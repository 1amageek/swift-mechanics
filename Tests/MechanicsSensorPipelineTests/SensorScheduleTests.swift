import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SensorScheduleTests {
    @Test func holdAndLinearExplicitSources() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        for sampling in [SensorPipelineDefinition.Sampling.previousAcceptedHold, .linearObservationComponents] {
            let session = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(sampling: sampling)); defer { session.shutdown() }
            _ = try SensorPipelineFixtures.advance(session, time: 0.5, q: 4)
            let rows = try SensorBatchCapture().capture(session).records
            #expect(rows.map { $0.sampleTime } == [0.125, 0.25, 0.375, 0.5])
            #expect(rows.allSatisfy { $0.sourceTime == 0 && $0.source.physical.q == [0] })
            if sampling == .previousAcceptedHold { #expect(rows.allSatisfy { $0.value == 0 && !$0.isInterpolated }) }
            else {
                #expect(rows.map { $0.value! } == [1, 2, 3, 4])
                #expect(rows.allSatisfy { $0.isInterpolated && $0.bracketEnd?.physical.q == [4] && $0.bracketEnd?.acceptedSequence == 1 })
            }
        }
    }
    @Test func delayUsesFirstAcceptedBoundary() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let channel = try SensorPipelineFixtures.channel(processing: SensorProcessing(delaySeconds: 0.1875))
        let session = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(channels: [channel])); defer { session.shutdown() }
        for i in 1...2 { _ = try SensorPipelineFixtures.advance(session, time: Double(i)*0.125) }
        #expect(try SensorBatchCapture().capture(session).records.isEmpty)
        _ = try SensorPipelineFixtures.advance(session, time: 0.375)
        let row = try SensorBatchCapture().capture(session).records[0]
        #expect(row.sampleTime == 0.125 && row.sourceTime == 0.125 && row.releaseDeadline == 0.3125 && row.deliveryTime == 0.375)
    }
    @Test func endpointMismatchAndRejectedTrialsRetainAllBytes() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let session = try SensorPipelineFixtures.session(); defer { session.shutdown() }
        let codec = NativeRuntimeCheckpointCodec(), before = try session.checkpoint(codec: codec)
        let rejected = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try trial.setTime(0.5); try trial.setPosition(40, at: 0); _ = try trial.nextRandom(); return .reject
        }
        #expect(rejected.decision == .reject)
        #expect(try session.checkpoint(codec: codec) == before)
        do { _ = try SensorPipelineFixtures.advance(session, time: 0.5); Issue.record("Endpoint clock mismatch succeeded.") }
        catch let failure as RuntimeFailure { #expect(failure.code == .unsupportedDomain && failure.lastAccepted?.checkpoint == session.snapshot().checkpoint) }
        #expect(try session.checkpoint(codec: codec) == before)
    }
    @Test func sameTimeDoesNotIssuePeriodicDuplicates() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let session = try SensorPipelineFixtures.session(); defer { session.shutdown() }
        _ = try SensorPipelineFixtures.advance(session, time: 0.125)
        _ = try session.performTrial { (_: inout RuntimeTrial, _: inout RuntimeStepControl) throws(RuntimeFailure) in .accept }
        let batch = try SensorBatchCapture().capture(session)
        #expect(batch.records.count == 1 && session.snapshot().checkpoint.acceptedSteps == 2)
        #expect(batch.records[0].source.acceptedSequence == 1)
    }
    @Test func pendingAndTickCapacityRejectWholeCandidate() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        for definition in [try SensorPipelineFixtures.definition(channels: [SensorPipelineFixtures.channel(processing: SensorProcessing(delaySeconds: 2))], pending: 1),
                           try SensorPipelineFixtures.definition(sampling: .previousAcceptedHold, ticks: 1)] {
            let session = try SensorPipelineFixtures.session(definition: definition); defer { session.shutdown() }
            if definition.bounds.maximumPendingRows == 1 { _ = try SensorPipelineFixtures.advance(session, time: 0.125) }
            let before = session.snapshot().checkpoint
            do { _ = try SensorPipelineFixtures.advance(session, time: definition.bounds.maximumPendingRows == 1 ? 0.25 : 0.5); Issue.record("Bounded capacity overflow succeeded.") }
            catch let failure as RuntimeFailure { #expect(failure.code == .capacityExceeded) }
            #expect(session.snapshot().checkpoint == before)
        }
    }
    @Test func readyRetentionReportsOverrunAndColdFloor() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let definition = try SensorPipelineFixtures.definition(overflow: .retainLatestWithReportedOverrun, ready: 2)
        let session = try SensorPipelineFixtures.session(definition: definition); defer { session.shutdown() }
        for i in 1...4 { _ = try SensorPipelineFixtures.advance(session, time: Double(i)*0.125) }
        do { _ = try SensorBatchCapture().capture(session); Issue.record("Lost records were silently returned.") }
        catch let error as SensorPipelineFailure { if case .overrun(let floor) = error { #expect(floor == 2) } else { Issue.record("Wrong overrun failure.") } }
        let batch = try SensorBatchCapture().capture(session, after: 2)
        #expect(batch.records.map { $0.readySequence } == [3, 4] && batch.retainedAfter == 2)
        let restored = try SensorPipelineFixtures.session(definition: definition); defer { restored.shutdown() }
        _ = try restored.restart(session.checkpoint(codec: NativeRuntimeCheckpointCodec()), codec: NativeRuntimeCheckpointCodec())
        #expect(try SensorBatchCapture().capture(restored, after: 2).records.map { $0.value! } == batch.records.map { $0.value! })
    }
    @Test func refuseReadyOverflow() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let session = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(ready: 1)); defer { session.shutdown() }
        _ = try SensorPipelineFixtures.advance(session, time: 0.125)
        let before = session.snapshot().checkpoint
        do { _ = try SensorPipelineFixtures.advance(session, time: 0.25); Issue.record("Ready overflow succeeded.") }
        catch let error as RuntimeFailure { #expect(error.code == .capacityExceeded) }
        #expect(session.snapshot().checkpoint == before)
    }
}

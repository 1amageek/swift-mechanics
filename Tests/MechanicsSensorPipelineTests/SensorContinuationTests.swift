import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SensorContinuationTests {
    @Test func coldReplayExactFullContributorAndRNG() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let channel = try SensorPipelineFixtures.channel(processing: SensorProcessing(noiseHalfWidth: 1, dropoutProbability: 0.25, delaySeconds: 0.1875))
        let definition = try SensorPipelineFixtures.definition(channels: [channel])
        let first = try SensorPipelineFixtures.session(definition: definition), second = try SensorPipelineFixtures.session(definition: definition)
        defer { first.shutdown(); second.shutdown() }
        for i in 1...3 { _ = try SensorPipelineFixtures.advance(first, time: Double(i)*0.125) }
        let codec = NativeRuntimeCheckpointCodec(), saved = try first.checkpoint(codec: codec)
        _ = try second.restart(saved, codec: codec)
        #expect(try second.checkpoint(codec: codec) == saved)
        for i in 4...6 {
            _ = try SensorPipelineFixtures.advance(first, time: Double(i)*0.125)
            _ = try SensorPipelineFixtures.advance(second, time: Double(i)*0.125)
        }
        #expect(try first.checkpoint(codec: codec) == second.checkpoint(codec: codec))
        let a = try SensorBatchCapture().capture(first), b = try SensorBatchCapture().capture(second)
        #expect(a.records.map { $0.value?.bitPattern } == b.records.map { $0.value?.bitPattern })
        #expect(a.records.map { $0.deliveryTime } == b.records.map { $0.deliveryTime })
    }
    @Test func unchangedStampTimeAlteredPhysicalIsNotAcceptedSource() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let session = try SensorPipelineFixtures.session(); defer { session.shutdown() }
        _ = try SensorPipelineFixtures.advance(session, time: 0.125)
        let checkpoint = session.snapshot().checkpoint
        let changed = try KinematicState(revision: checkpoint.physical.revision, time: checkpoint.physical.time,
            q: [checkpoint.physical.q[0]+1], v: checkpoint.physical.v, acceleration: checkpoint.physical.acceleration)
        let counterfeit = try RuntimeCheckpoint(model: checkpoint.model, continuation: checkpoint.continuation, physical: changed,
            contributors: checkpoint.contributors, random: checkpoint.random, acceptedSteps: checkpoint.acceptedSteps)
        let bytes = try NativeRuntimeCheckpointCodec().encode(counterfeit, capacity: session.configuration.capacity)
        do { _ = try session.restart(bytes, codec: NativeRuntimeCheckpointCodec()); Issue.record("Header-only counterfeit source was accepted.") }
        catch let error as RuntimeFailure { #expect(error.code == .invalidContributor && error.contributor == session.definition.schemaID) }
        #expect(session.snapshot().checkpoint == checkpoint)
    }
    @Test(arguments: [0, 1]) func changedSettingsOrSeedRefuseColdRestore(_ variant: Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let original = try SensorPipelineFixtures.session(); defer { original.shutdown() }
        _ = try SensorPipelineFixtures.advance(original, time: 0.125)
        let definition = try SensorPipelineFixtures.definition(channels: [SensorPipelineFixtures.channel(processing: SensorProcessing(bias: variant == 0 ? 1 : 0))], seed: variant == 1 ? 124 : 123)
        let changed = try SensorPipelineFixtures.session(definition: definition); defer { changed.shutdown() }
        let before = changed.snapshot().checkpoint
        do { _ = try changed.restart(original.checkpoint(codec: NativeRuntimeCheckpointCodec()), codec: NativeRuntimeCheckpointCodec()); Issue.record("Changed cold schema succeeded.") }
        catch let error as RuntimeFailure { #expect(error.code == .invalidContributor) }
        #expect(changed.snapshot().checkpoint == before)
    }
    @Test func corruptCodecAndCancellationRetainPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let session = try SensorPipelineFixtures.session(); defer { session.shutdown() }
        let before = session.snapshot().checkpoint
        do { _ = try session.restart([1,2,3], codec: NativeRuntimeCheckpointCodec()); Issue.record("Truncated codec succeeded.") }
        catch let error as RuntimeFailure { #expect(error.code == .truncatedCheckpoint) }
        do {
            _ = try session.performTrial { (trial: inout RuntimeTrial, _: inout RuntimeStepControl) throws(RuntimeFailure) in
                try trial.setTime(0.125); _ = try trial.nextRandom(); session.cancel(); return .accept
            }
            Issue.record("Cancellation published sensor state.")
        } catch let error as RuntimeFailure { #expect(error.code == .cancelled) }
        #expect(session.snapshot().checkpoint == before)
        _ = try SensorPipelineFixtures.advance(session, time: 0.125)
        #expect(session.snapshot().checkpoint.random.draws == 0)
    }
    @Test func processingOverflowRetainsPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let channel = try SensorPipelineFixtures.channel(processing: SensorProcessing(bias: 1e308))
        let session = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(channels: [channel])); defer { session.shutdown() }
        let before = session.snapshot().checkpoint
        do { _ = try SensorPipelineFixtures.advance(session, time: 0.125, q: 1e308); Issue.record("Nonfinite transform succeeded.") }
        catch let error as RuntimeFailure { #expect(error.code == .invalidContributor) }
        #expect(session.snapshot().checkpoint == before)
    }
}

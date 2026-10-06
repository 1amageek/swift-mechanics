import SwiftMechanics
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
struct SensorLifecycleTests {
    @Test func leaseClosureReentryAndOwnedOutput() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let session = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(emitInitial: true))
        let leaseOwner = Mutex<SensorBatchLease?>(nil), batchOwner = Mutex<SensorBatch?>(nil)
        let saved = try session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        try session.readBatch(SensorPipelineFixtures.request(session)) { (lease: SensorBatchLease) throws(SensorPipelineFailure) in
            leaseOwner.withLock { $0 = lease }
            try lease.read { (batch: SensorBatch) throws(SensorPipelineFailure) in
                batchOwner.withLock { $0 = batch }
                do throws(RuntimeFailure) { _ = try session.restart(saved, codec: NativeRuntimeCheckpointCodec()); Issue.record("Read lease allowed mutation.") }
                catch { #expect(error.code == .busy) }
                do throws(RuntimeFailure) { _ = try SensorPipelineFixtures.advance(session, time: 0.125); Issue.record("Callback reentry was not busy.") }
                catch { #expect(error.code == .busy) }
            }
        }
        guard let retained = leaseOwner.withLock({ $0 }) else { throw SensorPipelineFailure.corruptState }
        do { try retained.read { _ in Issue.record("Closed lease callback ran.") }; Issue.record("Escaped lease remained active.") }
        catch { if case .invalidLease = error {} else { Issue.record("Wrong lease failure.") } }
        #expect(session.shutdown() == .closed)
        #expect(batchOwner.withLock { $0?.records.first?.value } == 0)
        do { try session.readBatch(SensorPipelineFixtures.request(session)) { _ in }; Issue.record("Closed owner read succeeded.") }
        catch let error as SensorPipelineFailure { if case .closed = error {} else { Issue.record("Wrong closed failure.") } }
    }
    @Test func shutdownWaitsForReadAndReleasesOnce() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let releases = Mutex(0), gate = SensorTestGate()
        let session = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(emitInitial: true), onRelease: { releases.withLock { $0 += 1 } })
        let request = try SensorPipelineFixtures.request(session)
        let task = Task.detached {
            try session.readBatch(request) { (lease: SensorBatchLease) throws(SensorPipelineFailure) in try lease.read { (batch: SensorBatch) throws(SensorPipelineFailure) in #expect(batch.records.count == 1); try gate.wait() } }
        }
        defer { gate.open(); session.shutdown() }
        try await gate.waitForEntry()
        #expect(session.shutdown() == .draining && releases.withLock { $0 } == 0)
        gate.open(); try await task.value
        #expect(session.shutdownStatus() == .closed && releases.withLock { $0 } == 1)
        #expect(session.shutdown() == .closed && releases.withLock { $0 } == 1)
    }
    @Test func rawConstructorFailureReleasesOnce() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let releases = Mutex(0)
        let bad = try SensorChannel(id: "dimension", streamKey: 11, source: .encoder(joint: SensorPipelineFixtures.id(.joint, "joint"), quantity: .position, axis: 0), dimension: .length, processing: SensorProcessing())
        do { _ = try SensorPipelineFixtures.session(definition: SensorPipelineFixtures.definition(channels: [bad]), onRelease: { releases.withLock { $0 += 1 } }); Issue.record("Invalid raw dimension succeeded.") }
        catch { #expect(releases.withLock { $0 } == 1) }
    }
    @Test func shutdownDuringActualTrialKeepsAcceptedPrefix() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Sensor pipeline requires the declared Synchronization baseline."); return }
        let gate = SensorTestGate(), releases = Mutex(0)
        let session = try SensorPipelineFixtures.session(onRelease: { releases.withLock { $0 += 1 } })
        let before = session.snapshot().checkpoint
        let task = Task.detached {
            do throws(RuntimeFailure) {
                _ = try session.performTrial { (trial: inout RuntimeTrial, _: inout RuntimeStepControl) throws(RuntimeFailure) in
                    try trial.setTime(0.125); _ = try trial.nextRandom()
                    do { try gate.wait() } catch { throw RuntimeFailure(.busy, message: "Test gate failed.") }
                    return .accept
                }
                Issue.record("Shutdown candidate was published.")
            } catch { #expect(error.code == .closed || error.code == .cancelled) }
        }
        defer { gate.open(); session.shutdown() }
        try await gate.waitForEntry(); #expect(session.shutdown() == .draining)
        gate.open(); await task.value
        #expect(session.snapshot().checkpoint == before)
        #expect(session.shutdownStatus() == .closed && releases.withLock { $0 } == 1)
    }
}

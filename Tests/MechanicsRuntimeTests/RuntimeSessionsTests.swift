import SwiftMechanics
import Testing
import Synchronization

@Suite struct RuntimeSessionsTests {
    @Test func callbackReentryObservationShutdownAndExactlyOnceRelease() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let releases = Mutex(0)
        let session = try RuntimeFixtures.session(onRelease: { releases.withLock { $0 += 1 } })
        let prefix = session.snapshot()
        _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            #expect(session.snapshot() == prefix)
            RuntimeFixtures.failure(.busy) { () throws(RuntimeFailure) in
                _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in .reject }
            }
            return .reject
        }
        try session.observe { (accepted: RuntimeAcceptedState) throws(RuntimeFailure) in
            #expect(accepted == prefix)
            RuntimeFixtures.failure(.busy) { () throws(RuntimeFailure) in _ = try RuntimeFixtures.advance(session) }
            #expect(session.shutdown() == .draining)
            #expect(releases.withLock { $0 } == 0)
        }
        #expect(session.shutdownStatus() == .closed)
        #expect(session.shutdown() == .closed && releases.withLock { $0 } == 1)
        #expect(session.snapshot() == prefix)
        RuntimeFixtures.failure(.closed) { () throws(RuntimeFailure) in _ = try RuntimeFixtures.advance(session) }
    }
    @Test(.timeLimit(.minutes(1))) func concurrentShutdownCannotPublishCallbackCandidate() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let releases = Mutex(0), gate = RuntimeBlockingGate()
        let session = try RuntimeFixtures.session(onRelease: { releases.withLock { $0 += 1 } })
        let prefix = session.snapshot()
        let worker = Task.detached { () -> Result<RuntimeTrialOutcome, RuntimeFailure> in
            do throws(RuntimeFailure) {
                return .success(try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                    try trial.setPosition(12, at: 0); try trial.setTime(1); try gate.wait(); return .accept
                })
            } catch { return .failure(error) }
        }
        defer { gate.open() }
        try await gate.waitForEntry()
        #expect(session.snapshot() == prefix)
        RuntimeFixtures.failure(.busy) { () throws(RuntimeFailure) in _ = try RuntimeFixtures.advance(session) }
        #expect(session.shutdown() == .draining && releases.withLock { $0 } == 0)
        gate.open()
        switch await worker.value {
        case .success: Issue.record("Shutdown permitted trial publication.")
        case .failure(let error): #expect(error.code == .cancelled || error.code == .closed); #expect(error.lastAccepted == prefix)
        }
        #expect(session.snapshot() == prefix && session.shutdownStatus() == .closed)
        #expect(releases.withLock { $0 } == 1)
        _ = session.shutdown(); #expect(releases.withLock { $0 } == 1)
    }
    @Test(.timeLimit(.minutes(1))) func cancellationAtWorkSafePointRetainsLastAcceptedPrefix() async throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let gate = RuntimeBlockingGate(), session = try RuntimeFixtures.session(); _ = try RuntimeFixtures.advance(session)
        let prefix = session.snapshot()
        let worker = Task.detached { () -> Result<RuntimeTrialOutcome, RuntimeFailure> in
            do throws(RuntimeFailure) {
                return .success(try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                    _ = try trial.nextRandom(); try trial.setPosition(99, at: 0); try gate.wait()
                    try control.beginWorkBlock(units: 1); return .accept
                })
            } catch { return .failure(error) }
        }
        defer { gate.open() }; try await gate.waitForEntry()
        session.cancel(); gate.open()
        switch await worker.value {
        case .success: Issue.record("Cancelled trial was accepted.")
        case .failure(let error): #expect(error.code == .cancelled && error.lastAccepted == prefix)
        }
        #expect(session.snapshot() == prefix)
        _ = try RuntimeFixtures.advance(session)
        #expect(session.snapshot().checkpoint.acceptedSteps == 2)
    }
    @Test func foreignTicketReplacementCannotPoisonReservedWorkspace() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let stored = RuntimeStoredTicket(), first = try RuntimeFixtures.session(), second = try RuntimeFixtures.session()
        _ = try first.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in stored.save(trial,control); return .reject }
        let prefix = second.snapshot()
        RuntimeFixtures.failure(.invalidOwnerAccess) { () throws(RuntimeFailure) in
            _ = try second.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                let values = stored.load()
                guard let oldTrial = values.0, let oldControl = values.1 else { throw RuntimeFailure(.invalidInput, message: "Fixture ticket is missing.") }
                trial = oldTrial; control = oldControl; return .accept
            }
        }
        #expect(second.snapshot() == prefix)
        _ = try RuntimeFixtures.advance(second)
        #expect(second.snapshot().checkpoint.acceptedSteps == 1)
    }
    @Test func ownerDestructionAndFailedConstructionReleaseOnce() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let releases = Mutex(0)
        var session: RuntimeFixtures.Session? = try RuntimeFixtures.session(onRelease: { releases.withLock { $0 += 1 } })
        #expect(session != nil && releases.withLock { $0 } == 0)
        session = nil; #expect(releases.withLock { $0 } == 1)
        let model = try RuntimeFixtures.model(), config = try RuntimeFixtures.configuration(), handler = try RuntimeFixtures.handler()
        RuntimeFixtures.failure(.missingContributor) { () throws(RuntimeFailure) in
            _ = try RuntimeFixtures.Session(model: model, configuration: config, initialState: model.descriptor.initialState,
                contributors: [], seed: 0, checkpoints: handler, onRelease: { releases.withLock { $0 += 1 } })
        }
        #expect(releases.withLock { $0 } == 2)
    }
}

import SwiftMechanics
import Testing

@Suite struct RuntimeTransactionsTests {
    @Test func accelerationReadsCurrentTrialAndRejectsBoundsWithoutChangingAcceptedState() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let session = try RuntimeFixtures.session(), prefix = session.snapshot()
        _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            #expect(try trial.acceleration(at: 0) == prefix.physical.state.acceleration[0])
            try trial.setAcceleration(0.75, at: 0)
            #expect(try trial.acceleration(at: 0) == 0.75)
            for index in [-1, 1] {
                do throws(RuntimeFailure) { _ = try trial.acceleration(at: index); Issue.record("Out-of-bounds acceleration read succeeded.") }
                catch { #expect(error.code == .invalidInput) }
            }
            return .reject
        }
        #expect(session.snapshot() == prefix)
        _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            #expect(try trial.acceleration(at: 0) == prefix.physical.state.acceleration[0])
            return .reject
        }
        #expect(session.snapshot() == prefix)
    }
    @Test func acceptRejectRestoreWholeContributorAndRandomState() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let session = try RuntimeFixtures.session(), control = try RuntimeFixtures.session()
        _ = try RuntimeFixtures.advance(session); _ = try RuntimeFixtures.advance(control)
        let prefix = session.snapshot()
        let rejected = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            try control.beginWorkBlock(units: 2)
            _ = try trial.nextRandom(); try trial.setPosition(999, at: 0); try trial.setTime(99)
            try trial.replaceContributor(CounterRuntimeContributors.record(999))
            return .reject
        }
        #expect(rejected.decision == .reject && rejected.accepted == prefix)
        #expect(session.snapshot() == prefix)
        _ = try RuntimeFixtures.advance(session); _ = try RuntimeFixtures.advance(control)
        #expect(session.snapshot() == control.snapshot())
        #expect(try CounterRuntimeContributors.count(session.snapshot().checkpoint.contributors[0]) == 2)
        let profile = session.profile()
        #expect(profile.attemptedTransactions == 3 && profile.committedTransactions == 2 && profile.rejectedTransactions == 1)
    }
    @Test func invalidTrialRetainsLastAcceptedPrefixAndReservedShape() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let session = try RuntimeFixtures.session(); _ = try RuntimeFixtures.advance(session)
        let prefix = session.snapshot()
        RuntimeFixtures.failure(.invalidState) { () throws(RuntimeFailure) in
            _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                try trial.setPosition(.infinity, at: 0); return .accept
            }
        }
        RuntimeFixtures.failure(.invalidState) { () throws(RuntimeFailure) in
            _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                try trial.setTime(-1); return .accept
            }
        }
        RuntimeFixtures.failure(.invalidContributor) { () throws(RuntimeFailure) in
            _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                try trial.replaceContributor(RuntimeContributorState(id: "integrator-counter", category: .integrator, version: 1, bytes: [1])); return .accept
            }
        }
        #expect(session.snapshot() == prefix)
        _ = try RuntimeFixtures.advance(session)
        #expect(session.snapshot().checkpoint.acceptedSteps == 2)
        #expect(session.profile().reservedPhysicalScalars == 3)
    }
    @Test func copiedControlCannotResetWorkBudget() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let session = try RuntimeFixtures.session(), prefix = session.snapshot()
        RuntimeFixtures.failure(.capacityExceeded) { () throws(RuntimeFailure) in
            _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                let copy = control
                for _ in 0..<25 { try control.beginWorkBlock(units: 4) }
                try copy.beginWorkBlock(units: 1)
                return .accept
            }
        }
        #expect(session.snapshot() == prefix)
    }
    @Test func actualFloatingChartRejectionAndRoundTrip() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime requires the declared Synchronization OS baseline."); return }
        let model = try RuntimeFixtures.model(floating: true), session = try RuntimeFixtures.session(model: model)
        let prefix = session.snapshot()
        #expect(prefix.physical.state.q.count == 7 && prefix.physical.state.v.count == 6)
        RuntimeFixtures.failure(.invalidState) { () throws(RuntimeFailure) in
            _ = try session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                try trial.setPosition(0, at: 3); return .accept
            }
        }
        #expect(session.snapshot() == prefix)
        let codec = NativeRuntimeCheckpointCodec(), decoded = try codec.decode(session.checkpoint(codec: codec), capacity: session.configuration.capacity)
        #expect(decoded == prefix.checkpoint)
        #expect(decoded.physical.q[3].bitPattern == (-1.0).bitPattern)
    }
}

import SwiftMechanics
import Testing

struct PlanarRuntimeAdmissionTests {
    @Test func untrustedGlobalRestartAndStaleFieldPreserveWholeAcceptedOwner() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime availability missing."); return }
        let fixture = try PlanarRuntimeFixture(); defer { _ = fixture.session.shutdown() }
        _ = try fixture.advance(); let prefix = fixture.session.snapshot()
        let wire = try fixture.session.checkpoint(codec: NativeRuntimeCheckpointCodec())
        let tooLarge = [UInt8](repeating: 0, count: fixture.session.configuration.capacity.maximumCheckpointBytes+1)
        let inputs = [(Array(wire.dropLast()), RuntimeFailureCode.truncatedCheckpoint), (tooLarge, .capacityExceeded)]
        for (bytes, code) in inputs {
            do throws(RuntimeFailure) { _ = try fixture.session.restart(bytes, codec: NativeRuntimeCheckpointCodec()); Issue.record("Untrusted global wire admitted.") }
            catch { #expect(error.code == code && error.lastAccepted == prefix) }
            #expect(fixture.session.snapshot() == prefix)
        }
        var field = prefix.checkpoint.contributors[0].bytes; field[0] ^= 1
        let record = try RuntimeContributorState(id: fixture.codec.schema.id, category: .integrator, version: 1, bytes: field)
        let old = prefix.checkpoint
        let forged = try RuntimeCheckpoint(model: old.model, continuation: old.continuation, physical: old.physical,
            contributors: [record], random: old.random, acceptedSteps: old.acceptedSteps)
        let stale = try NativeRuntimeCheckpointCodec().encode(forged, capacity: fixture.session.configuration.capacity)
        do throws(RuntimeFailure) { _ = try fixture.session.restart(stale, codec: NativeRuntimeCheckpointCodec()); Issue.record("Stale field header admitted.") }
        catch { #expect(error.code == .incompatibleContinuation && error.lastAccepted == prefix) }
        #expect(fixture.session.snapshot() == prefix)
    }
    @Test func changedTrialPhysicalTimeIsRejectedBeforeActualFlowAdvance() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime availability missing."); return }
        let fixture = try PlanarRuntimeFixture(); defer { _ = fixture.session.shutdown() }
        let prefix = fixture.session.snapshot(), operation = fixture.operation, model = fixture.model
        let source = try PlanarRuntimeFixtures.source(), policy = try PlanarRuntimeFixtures.policy()
        do throws(RuntimeFailure) {
            _ = try fixture.session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                _ = try trial.nextRandom(); try trial.setTime(1)
                var numerical: NumericalWork, bytes: PlanarContinuationWork
                do { numerical = try PlanarRuntimeFixtures.numerical(); bytes = try PlanarRuntimeFixtures.bytes() }
                catch { throw RuntimeFailure(.invalidInput, message: "Fixture budgets failed.") }
                do throws(RuntimeFailure) {
                    _ = try operation.advance(model: model, source: source, duration: 0.01, policy: policy,
                        trial: &trial, control: &control, numerical: &numerical, continuation: &bytes)
                } catch { #expect(numerical.operations == 0); throw error }
                return .accept
            }
            Issue.record("Mismatched trial physical time advanced the flow.")
        } catch { #expect(error.code == .invalidState && error.lastAccepted == prefix) }
        #expect(fixture.session.snapshot() == prefix)
    }
    @Test func requiredWholeHandlerMigrationRemainsTypedUnsupported() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime availability missing."); return }
        let fixture = try PlanarRuntimeFixture(); defer { _ = fixture.session.shutdown() }
        let next = try PlanarRuntimeFixtures.model(revision: 2)
        let transition = try ReferenceModelRevisionUpdater().transition(from: fixture.model, to: next, policy: .preserveIfKinematicsUnchanged)
        let handler: any RuntimeCheckpointHandling = PlanarRuntimeCheckpointHandler(codec: fixture.codec, revisions: ReferenceModelRevisionUpdater())
        do throws(RuntimeFailure) {
            _ = try handler.migrate(fixture.session.snapshot().checkpoint, from: fixture.model, to: next,
                using: transition, configuration: fixture.session.configuration)
            Issue.record("Unqualified grid/model migration admitted.")
        } catch { #expect(error.code == .unsupportedDomain) }
    }
}

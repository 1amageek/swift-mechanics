import SwiftMechanics
import Testing

struct PlanarRuntimeFailureTests {
    @Test func actualExhaustedSolverRetainsUnknownWorkAndWholePrefixIncludingRandom() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime availability missing."); return }
        let fixture = try PlanarRuntimeFixture(); defer { _ = fixture.session.shutdown() }
        let prefix = fixture.session.snapshot(), operation = fixture.operation, model = fixture.model
        let policy = try PlanarRuntimeFixtures.policy(), source = try PlanarRuntimeFixtures.source()
        do throws(RuntimeFailure) {
            _ = try fixture.session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                _ = try trial.nextRandom()
                var numerical: NumericalWork, bytes: PlanarContinuationWork
                do { numerical = try PlanarRuntimeFixtures.numerical(iterations: 0); bytes = try PlanarRuntimeFixtures.bytes() }
                catch { throw RuntimeFailure(.invalidInput, message: "Fixture budgets failed.") }
                do throws(RuntimeFailure) {
                    _ = try operation.advance(model: model, source: source, duration: 0.01, policy: policy,
                        trial: &trial, control: &control, numerical: &numerical, continuation: &bytes)
                } catch {
                    #expect(numerical.operations > 0 && bytes.workUnits > 0)
                    throw error
                }
                return .accept
            }
            Issue.record("Exhausted pressure solver unexpectedly published.")
        } catch { #expect(error.code == .invalidContributor && error.failedSupplierWorkUnavailable && error.lastAccepted == prefix) }
        #expect(fixture.session.snapshot() == prefix && fixture.session.profile().attemptedTransactions == 1)
    }
    @Test func realSuccessfulSolverCancellationRefusesPublicationAndPreservesRandom() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime availability missing."); return }
        let owner = PlanarRuntimeCancellationOwner()
        let flow = ReferencePlanarFlowSolver(linear: PlanarRuntimeCancellingSolver(owner: owner))
        let fixture = try PlanarRuntimeFixture(flow: flow); defer { _ = fixture.session.shutdown() }
        let prefix = fixture.session.snapshot(), operation = fixture.operation, model = fixture.model
        let policy = try PlanarRuntimeFixtures.policy(cancel: { owner.read() }), source = try PlanarRuntimeFixtures.source()
        do throws(RuntimeFailure) {
            _ = try fixture.session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                _ = try trial.nextRandom()
                var numerical: NumericalWork, bytes: PlanarContinuationWork
                do { numerical = try PlanarRuntimeFixtures.numerical(); bytes = try PlanarRuntimeFixtures.bytes() }
                catch { throw RuntimeFailure(.invalidInput, message: "Fixture budgets failed.") }
                _ = try operation.advance(model: model, source: source, duration: 0.01, policy: policy,
                    trial: &trial, control: &control, numerical: &numerical, continuation: &bytes)
                return .accept
            }
            Issue.record("Cancelled actual pressure solve unexpectedly published.")
        } catch { #expect(error.code == .cancelled && !error.failedSupplierWorkUnavailable && error.lastAccepted == prefix) }
        #expect(owner.read() && fixture.session.snapshot() == prefix)
    }
    @Test func runtimeWorkAndDurationFailuresPreserveAcceptedPrefix() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Runtime availability missing."); return }
        let fixture = try PlanarRuntimeFixture(); defer { _ = fixture.session.shutdown() }
        _ = try fixture.advance(); let prefix = fixture.session.snapshot()
        do throws(RuntimeFailure) { _ = try fixture.advance(duration: 0); Issue.record("Expected duration rejection.") }
        catch { #expect(error.code == .invalidContributor && error.lastAccepted == prefix) }
        #expect(fixture.session.snapshot() == prefix)
        let limited = try PlanarRuntimeFixture(stepWork: 2); defer { _ = limited.session.shutdown() }
        let old = limited.session.snapshot()
        do throws(RuntimeFailure) { _ = try limited.advance(); Issue.record("Expected Runtime work rejection.") }
        catch { #expect(error.code == .capacityExceeded && error.lastAccepted == old) }
        #expect(limited.session.snapshot() == old)
    }
    @Test func requiredLocalValidationChecksCarrierAndMigrationIsExplicitFailure() throws {
        let model = try PlanarRuntimeFixtures.model(), g = try PlanarRuntimeFixtures.grid()
        let codec = try PlanarRuntimeFixtures.codec(grid: g, model: model.stamp)
        let provider: any RuntimeContributorHandling = PlanarRuntimeContributors(codec: codec)
        var bytes = try PlanarRuntimeFixtures.bytes()
        let record = try codec.encode(PlanarRuntimeFixtures.state(g), work: &bytes)
        let evidence = try provider.validate(record, model: model, budget: RuntimeValidationBudget(workUnits: 100000, scratchBytes: 30000))
        #expect(evidence.workUnitsUsed > codec.encodedSize && evidence.scratchBytesUsed == codec.requiredScratchBytes)
        do throws(RuntimeFailure) {
            _ = try provider.validate(record, model: model, budget: RuntimeValidationBudget(workUnits: 0, scratchBytes: 30000))
            Issue.record("Expected validation budget rejection.")
        } catch { #expect(error.code == .contributorBudgetExceeded) }
        let next = try PlanarRuntimeFixtures.model(revision: 2)
        do throws(RuntimeFailure) {
            _ = try provider.validate(record, model: next, budget: RuntimeValidationBudget(workUnits: 100000, scratchBytes: 30000))
            Issue.record("Expected stale carrier rejection.")
        } catch { #expect(error.code == .incompatibleModel) }
        let transition = try ReferenceModelRevisionUpdater().transition(from: model, to: next, policy: .preserveIfKinematicsUnchanged)
        do throws(RuntimeFailure) {
            _ = try provider.migrate(record, transition: transition, target: next, budget: RuntimeValidationBudget(workUnits: 100000, scratchBytes: 30000))
            Issue.record("Expected unsupported migration.")
        } catch { #expect(error.code == .unsupportedDomain) }
    }
}

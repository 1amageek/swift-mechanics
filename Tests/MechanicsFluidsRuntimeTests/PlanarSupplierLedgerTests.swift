import SwiftMechanics
import Testing

struct PlanarSupplierLedgerTests {
    @Test func boundaryBudgetFailureDoesNotInvokeSupplier() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else {
            Issue.record("Runtime availability missing."); return
        }
        let flow = ResettingPlanarFlow(failsAfterReset: false)
        let fixture = try PlanarRuntimeFixture(flow: flow)
        defer { _ = fixture.session.shutdown() }
        let prefix = fixture.session.snapshot(), operation = fixture.operation, model = fixture.model
        let source = try PlanarRuntimeFixtures.source(), policy = try PlanarRuntimeFixtures.policy()
        do throws(RuntimeFailure) {
            _ = try fixture.session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                _ = try trial.nextRandom()
                var numerical: NumericalWork, bytes: PlanarContinuationWork
                do {
                    numerical = NumericalWork(budget: try NumericalBudget(scalarStorage: 100000,
                        arithmeticOperations: 0, iterations: 10000))
                    bytes = try PlanarRuntimeFixtures.bytes()
                } catch { throw RuntimeFailure(.invalidInput, message: "Fixture budgets failed.") }
                _ = try operation.advance(model: model, source: source, duration: 0.01, policy: policy,
                    trial: &trial, control: &control, numerical: &numerical, continuation: &bytes)
                return .accept
            }
            Issue.record("Expected boundary budget rejection.")
        } catch {
            #expect(error.code == .invalidContributor && !error.failedSupplierWorkUnavailable)
            #expect(error.lastAccepted == prefix)
        }
        #expect(flow.calls.withLock { $0 } == 0 && fixture.session.snapshot() == prefix)
    }

    @Test(arguments: [false, true], [false, true])
    func resetAfterRealMACNeverPublishes(precharged: Bool, fails: Bool) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else {
            Issue.record("Runtime availability missing."); return
        }
        let flow = ResettingPlanarFlow(failsAfterReset: fails)
        let fixture = try PlanarRuntimeFixture(flow: flow)
        defer { _ = fixture.session.shutdown() }
        let prefix = fixture.session.snapshot(), operation = fixture.operation, model = fixture.model
        let source = try PlanarRuntimeFixtures.source(), policy = try PlanarRuntimeFixtures.policy()
        do throws(RuntimeFailure) {
            _ = try fixture.session.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
                _ = try trial.nextRandom()
                var numerical: NumericalWork, bytes: PlanarContinuationWork, known: NumericalWork
                do {
                    numerical = try PlanarRuntimeFixtures.numerical()
                    bytes = try PlanarRuntimeFixtures.bytes()
                    if precharged {
                        try numerical.chargeOperations(7)
                        try numerical.advanceIteration()
                        try numerical.requireStorage(3)
                    }
                    known = numerical
                    try known.chargeOperations(1)
                } catch { throw RuntimeFailure(.invalidInput, message: "Fixture budgets failed.") }
                do throws(RuntimeFailure) {
                    _ = try operation.advance(model: model, source: source, duration: 0.01, policy: policy,
                        trial: &trial, control: &control, numerical: &numerical, continuation: &bytes)
                } catch {
                    #expect(numerical == known)
                    throw error
                }
                Issue.record("A supplier reset after actual MAC work unexpectedly reached publication.")
                return .accept
            }
            Issue.record("Expected supplier ledger rejection.")
        } catch {
            #expect(error.code == .invalidContributor && error.failedSupplierWorkUnavailable)
            #expect(error.lastAccepted == prefix)
        }
        #expect(flow.calls.withLock { $0 } == 1)
        #expect(fixture.session.snapshot() == prefix)
    }
}

import SwiftMechanics

public enum LinearQuadraticCostBoundaryQualification {
    public static func run() throws {
        let fixture = LinearQuadraticQualificationFixture.self
        let system = try fixture.analytic(a: [0, 0, 0, 0], b: [0, 0], states: 2, inputs: 1, identity: "lqr-exact-cost")
        let policy = try fixture.policy()
        let designer: any LinearQuadraticDesigning = ReferenceLinearQuadraticDesigner()
        let tiny = Double.leastNonzeroMagnitude
        let rankOne = [1.0, 0.5, 0.5, 0.25]
        for q in [rankOne, [1, 0.5.nextDown, 0.5.nextDown, 0.25], [tiny, 0, 0, 4]] {
            var work = try fixture.work(policy)
            let result = try designer.design(system, stateCost: q, inputCost: [1], stabilizingGainWitness: [0, 0], policy: policy, work: &work)
            guard result.stateCost == q, result.riccatiMatrix == q, result.feedbackGain == [0, 0], result.diagnostics.work == work else {
                throw LinearQuadraticQualificationError.assertion("Exact admitted original cost and zero-plant Riccati authority")
            }
        }
        for q in [[tiny, 5e-162, 5e-162, 4], [0, tiny, tiny, 1],
                  [1, 0.5.nextUp, 0.5.nextUp, 0.25], [1e308, 1e308, 1e308, 5e307]] {
            var work = try fixture.work(policy, seeded: true)
            do {
                _ = try designer.design(system, stateCost: q, inputCost: [1], stabilizingGainWitness: [0, 0], policy: policy, work: &work)
                throw LinearQuadraticQualificationError.unexpectedSuccess("Exact indefinite original state cost")
            } catch let error as LinearQuadraticFailure {
                guard case .indefiniteStateCost = error.cause, error.phase == "PSD-principal-minor", error.knownWork == work,
                      !error.failedSupplierWorkUnavailable else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
                // Seed11 + identity UTF8 bytes + Q/R finite/symmetry charges(24+6) + one128-operation pair.
                guard work.operations == 11 + system.identity.utf8.count + 30 + 128 else {
                    throw LinearQuadraticQualificationError.assertion("Exact pre-supplier pair admission ledger")
                }
            }
        }
        let exactAdmission = 11 + system.identity.utf8.count + 30 + 128
        let short = try fixture.policy(operations: exactAdmission - 1)
        var work = try fixture.work(short, seeded: true)
        do {
            _ = try designer.design(system, stateCost: [tiny, 5e-162, 5e-162, 4], inputCost: [1], stabilizingGainWitness: [0, 0], policy: short, work: &work)
            throw LinearQuadraticQualificationError.unexpectedSuccess("One-short exact pair reservation")
        } catch let error as LinearQuadraticFailure {
            guard case .numerical(.resourceLimit) = error.cause, error.knownWork == work,
                  work.operations == exactAdmission - 128 else { throw LinearQuadraticQualificationError.unexpectedFailure(error) }
        }
    }
}

import MechanicsCore
import MechanicsNumerics
import MechanicsNonlinear
import MechanicsComplementarity

extension FoundationVerification {
    static func verifyNumericalExtensions() throws {
        let nonlinear: any NonlinearSolving<Double> = ReferenceNonlinearSolver()
        let budget = try NumericalBudget(scalarStorage: 10000, arithmeticOperations: 2_000_000, iterations: 4000)
        let policy = try NonlinearPolicy<Double>(
            strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 1e-4, minimumFraction: 1e-8),
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            tolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-14),
            referenceScale: 1, minimumDirectionNorm: 0, derivativeProbeDistance: 1e-6,
            derivativeAbsoluteTolerance: 1e-6, derivativeRelativeTolerance: 1e-5,
            maximumFactorEntries: 1, estimateCondition: true, budget: budget)
        let root: NonlinearSolution<Double>
        do { root = try nonlinear.solve(RuntimeCubicEquation<Double>(falseInternalResidual: false), initialPoint: [0.1], policy: policy) }
        catch { throw FoundationVerificationError.unexpectedFailure }
        guard abs(root.values[0] - 1) < 1e-9, root.originalResidual.isAccepted,
              root.diagnostics.rejectedSteps > 0 else { throw FoundationVerificationError.analyticCheckFailed }
        var falseSuccessRejected = false
        do {
            _ = try nonlinear.solve(RuntimeCubicEquation<Double>(falseInternalResidual: true), initialPoint: [0.1], policy: policy)
        } catch {
            if case .originalResidualDisagreement = error.cause { falseSuccessRejected = true }
        }
        guard falseSuccessRejected else { throw FoundationVerificationError.analyticCheckFailed }

        let contact: any ComplementaritySolving = ProjectedComplementaritySolver()
        let contactPolicy = try ComplementarityPolicy(precision: .float64, backend: .referenceCPU,
            tolerance: ConeTolerance(absolutePrimal: 1e-9, absoluteDual: 1e-9, absoluteComplementarity: 1e-9,
                absoluteOptimality: 1e-9, relative: 1e-10, primalScale: 1, dualScale: 1),
            maximumIterations: 3000, choleskyPivotThreshold: 1e-14, budget: budget)
        let matrix = try DenseMatrix<Double>(rows: 2, columns: 2, values: [2, -1, -1, 2])
        let identity = ComplementarityIdentity(revision: 1, coordinateIDs: [0, 1], frameLayoutRevision: 1, lawRevision: 1)
        let problem = try ComplementarityProblem(matrix: matrix, linearTerm: [-1, 1],
            cone: .nonnegativeOrthant(dimension: 2), identity: identity)
        let cold = try contact.solve(problem, policy: contactPolicy, warmStart: nil)
        guard abs(cold.values[0] - 0.5) < 1e-8, cold.values[1] == 0,
              abs(cold.dualValues[1] - 0.5) < 1e-8, cold.diagnostics.originalResidual.isAccepted else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let restart = try ComplementarityCache(problem: cold.cache.problem, iterate: cold.cache.iterate,
            inverseRowBound: cold.cache.inverseRowBound)
        let warm = try contact.solve(problem, policy: contactPolicy, warmStart: restart)
        guard warm.values == cold.values, warm.diagnostics.originalResidual.isAccepted,
              warm.diagnostics.usedWarmStart else { throw FoundationVerificationError.analyticCheckFailed }
        let stale = try ComplementarityProblem(matrix: matrix, linearTerm: [-1, 1], cone: .nonnegativeOrthant(dimension: 2),
            identity: ComplementarityIdentity(revision: 2, coordinateIDs: [0, 1], frameLayoutRevision: 1, lawRevision: 1))
        var staleRejected = false
        do { _ = try contact.solve(stale, policy: contactPolicy, warmStart: restart) }
        catch { if case .staleCache = error { staleRejected = true } }
        guard staleRejected else { throw FoundationVerificationError.analyticCheckFailed }
        let cone = try ComplementarityProblem(matrix: DenseMatrix<Double>(rows: 3, columns: 3, values: [2,0,0,0,3,0,0,0,4]),
            linearTerm: [-3.5, -4, 0], cone: .associatedFrictionCones(coefficients: [0.5]),
            identity: ComplementarityIdentity(revision: 1, coordinateIDs: [0, 1, 2], frameLayoutRevision: 1, lawRevision: 1))
        let friction = try contact.solve(cone, policy: contactPolicy, warmStart: nil)
        guard abs(friction.values[0] - 2) < 1e-8, abs(friction.values[1] - 1) < 1e-8,
              abs(friction.values[0] * friction.dualValues[0] + friction.values[1] * friction.dualValues[1]) < 1.1e-9,
              friction.diagnostics.originalResidual.isAccepted else { throw FoundationVerificationError.analyticCheckFailed }
    }
}

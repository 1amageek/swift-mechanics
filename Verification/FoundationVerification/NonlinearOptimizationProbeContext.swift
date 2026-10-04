import SwiftMechanics

/// Public fixed-active local solve with explicit original metadata, derivatives and capacities.
struct NonlinearOptimizationProbeContext: Sendable {
    let layout: NonlinearProgramLayout
    let provider: any SmoothNonlinearProgramProviding<Double>
    let problem: FixedActiveNonlinearProblem
    let policy: LocalOptimizationPolicy
    let budget: NumericalBudget
    let negativeCurvature: Bool

    @inline(never)
    init(negativeCurvature: Bool = false) throws {
        let reference = try SIReferenceQuantity<Double>(magnitude: 1, dimension: .length)
        let metadata = try OptimizationMetadata(identity: negativeCurvature ? "af27-curved-equality-maximum" : "af27-curved-equality-minimum",
            provenance: SourceProvenance(source: "af27-independent-original-polynomial", revision: 1),
            variableIDs: [1001, 1002], variableReferences: [reference, reference],
            objectiveReference: SIReferenceQuantity(magnitude: 1, dimension: .energy), equalityReferences: [reference])
        let layout = NonlinearProgramLayout(metadata: metadata,
            equalityJacobian: SparseOptimizationPattern(rows: 1, columns: 2, rowOffsets: [0, 2], columnIndices: [0, 1]),
            inequalityJacobian: SparseOptimizationPattern(rows: 0, columns: 2, rowOffsets: [0], columnIndices: []),
            lagrangianHessian: SparseOptimizationPattern(rows: 2, columns: 2, rowOffsets: [0, 1, 2], columnIndices: [0, 1]))
        let provider: any SmoothNonlinearProgramProviding<Double> = NonlinearOptimizationProbe<Double>(
            layout: layout, negativeCurvature: negativeCurvature)
        let problem = FixedActiveNonlinearProblem(provider: provider, lowerBounds: [-10, -10], upperBounds: [10, 10],
            activeInequalities: [], initialPoint: [0.8, 0.8],
            initialEqualityMultipliers: [negativeCurvature ? -0.8 : 0.8], initialActiveMultipliers: [])
        self.layout = layout; self.provider = provider; self.problem = problem
        policy = try Self.policy(); budget = try Self.work().budget; self.negativeCurvature = negativeCurvature
    }

    private static func policy() throws -> LocalOptimizationPolicy {
        let tolerance = try LinearTolerance<Double>(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-14)
        let capability = LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU)
        let nonlinear = try NonlinearPolicy<Double>(strategy: .lineSearch(contraction: 0.5,
                sufficientDecrease: 1e-4, minimumFraction: 1e-8), capability: capability, tolerance: tolerance,
            referenceScale: 1, minimumDirectionNorm: 0, derivativeProbeDistance: 1e-6,
            derivativeAbsoluteTolerance: 1e-5, derivativeRelativeTolerance: 1e-5,
            maximumFactorEntries: 10000, estimateCondition: false,
            budget: NumericalBudget(scalarStorage: 100000, arithmeticOperations: 10000000, iterations: 1000))
        return try LocalOptimizationPolicy(nonlinear: nonlinear,
            curvatureCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            curvatureTolerance: tolerance, maximumVariables: 10, maximumRows: 100, maximumNonzeros: 1000,
            maximumDenseEntries: 10000, maximumProviderScratchScalars: 1000,
            rankThreshold: 1e-12, nullspaceTolerance: 1e-9, absoluteTolerance: 1e-9, relativeTolerance: 1e-10,
            strictMultiplierMargin: 1e-8, inactiveSlackMargin: 1e-8)
    }

    static func work() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 100000, arithmeticOperations: 10000000, iterations: 1000))
    }

    @inline(never)
    func solve(using solver: any LocalOptimizationSolving = FixedActiveLocalOptimizer()) throws(LocalOptimizationFailure) -> StrictLocalOptimum {
        var work = NumericalWork(budget: budget)
        return try solver.solve(problem, policy: policy, work: &work)
    }

    @inline(never)
    func solve(using solver: any LocalOptimizationSolving, work: inout NumericalWork) throws(LocalOptimizationFailure) -> StrictLocalOptimum {
        try solver.solve(problem, policy: policy, work: &work)
    }
}

import MechanicsNumerics
public protocol OptimizationSolving: Sendable {
    func solve(_ problem: ConvexOptimizationProblem, policy: OptimizationPolicy, workspace: inout EnumerationWorkspace,
        work: inout NumericalWork) throws(OptimizationFailure) -> OptimizationResult
}

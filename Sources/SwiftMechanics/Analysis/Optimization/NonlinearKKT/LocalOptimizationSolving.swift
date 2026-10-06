public protocol LocalOptimizationSolving: Sendable {
    func solve(_ problem: FixedActiveNonlinearProblem,policy: LocalOptimizationPolicy,work: inout NumericalWork) throws(LocalOptimizationFailure) -> StrictLocalOptimum
}

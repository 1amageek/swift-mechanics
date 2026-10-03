public protocol TreeLinearSolving<Scalar>: Sendable {
    associatedtype Scalar: NumericalScalar
    func solve(_ system: TreeLinearSystem<Scalar>, rightHandSide: [Scalar], capability: LinearCapability,
               tolerance: LinearTolerance<Scalar>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Scalar>
}

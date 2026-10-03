public protocol LinearSolving<Scalar>: Sendable {
    associatedtype Scalar: NumericalScalar
    func solve(_ matrix: DenseMatrix<Scalar>, rightHandSide: [Scalar], capability: LinearCapability, tolerance: LinearTolerance<Scalar>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Scalar>
    func solve(_ matrix: CSRMatrix<Scalar>, rightHandSide: [Scalar], capability: LinearCapability, tolerance: LinearTolerance<Scalar>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Scalar>
}

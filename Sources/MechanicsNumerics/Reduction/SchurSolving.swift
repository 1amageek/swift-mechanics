public protocol SchurSolving<Scalar>: Sendable {
    associatedtype Scalar: NumericalScalar
    func solve(a: DenseMatrix<Scalar>, b: DenseMatrix<Scalar>, c: DenseMatrix<Scalar>, d: DenseMatrix<Scalar>,
               primalRightHandSide: [Scalar], reducedRightHandSide: [Scalar], capability: LinearCapability,
               tolerance: LinearTolerance<Scalar>, budget: NumericalBudget) throws(NumericalError) -> SchurSolution<Scalar>
}

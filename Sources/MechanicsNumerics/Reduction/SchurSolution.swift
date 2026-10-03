public struct SchurSolution<Scalar: NumericalScalar>: Sendable {
    public let primal: [Scalar]
    public let reduced: [Scalar]
    public let schur: DenseMatrix<Scalar>
    public let primalResidual: ResidualEvidence<Scalar>
    public let reducedResidual: ResidualEvidence<Scalar>
    public let work: NumericalWork
}

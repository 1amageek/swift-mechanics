public struct LinearDiagnostics<Scalar: NumericalScalar>: Sendable {
    public let capability: LinearCapability
    public let factorization: LinearFactorization
    public let pivoting: LinearPivoting
    public let ordering: LinearOrdering
    public let rowPermutation: [Int]
    public let numericalRank: Int?
    public let work: NumericalWork
    public let originalResidual: ResidualEvidence<Scalar>
}

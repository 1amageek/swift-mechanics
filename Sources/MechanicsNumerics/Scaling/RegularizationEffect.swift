public struct RegularizationEffect<Scalar: NumericalScalar>: Sendable {
    public let originalResidual: ResidualEvidence<Scalar>
    public let perturbedResidual: ResidualEvidence<Scalar>
    public let modelEffect: [SIReferenceQuantity<Scalar>]
    public let maximumNormalizedPerturbation: Scalar
}

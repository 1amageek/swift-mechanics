public struct StructuralImplicitEndpoint: Sendable {
    public let state: StructuralIntegrationState
    public let parameters: GeneralizedAlphaParameters
    public let originalResidual: ResidualEvidence<Double>
    public let nonlinearDiagnostics: NonlinearDiagnostics<Double>
    public let work: NumericalWork
}

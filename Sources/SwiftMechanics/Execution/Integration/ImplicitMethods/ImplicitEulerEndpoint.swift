public struct ImplicitEulerEndpoint: Sendable {
    public let time: Double
    public let point: [Double]
    public let derivative: [Double]
    public let originalResidual: ResidualEvidence<Double>
    public let nonlinearDiagnostics: NonlinearDiagnostics<Double>
    public let work: NumericalWork
}

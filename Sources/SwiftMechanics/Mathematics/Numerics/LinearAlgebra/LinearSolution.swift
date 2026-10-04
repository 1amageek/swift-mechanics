public struct LinearSolution<Scalar: NumericalScalar>: Sendable {
    public var termination: NumericalTermination { .accepted }
    public let values: [Scalar]
    public let diagnostics: LinearDiagnostics<Scalar>
    public init(values: [Scalar], diagnostics: LinearDiagnostics<Scalar>) {
        self.values = values; self.diagnostics = diagnostics
    }
}

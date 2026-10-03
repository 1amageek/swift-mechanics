import MechanicsNumerics

public struct NonlinearSolution<Scalar: NumericalScalar>: Sendable {
    public let values: [Scalar]
    public let internalResidual: ResidualEvidence<Scalar>
    public let originalResidual: ResidualEvidence<Scalar>
    public let diagnostics: NonlinearDiagnostics<Scalar>
    public var termination: NumericalTermination { .accepted }
}

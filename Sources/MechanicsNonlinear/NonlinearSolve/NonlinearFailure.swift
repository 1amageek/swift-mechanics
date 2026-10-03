import MechanicsNumerics

public struct NonlinearFailure<Scalar: NumericalScalar>: Error, Sendable {
    public let equationIdentity: String
    public let capability: LinearCapability
    public let phase: NonlinearPhase
    public let cause: NonlinearCause
    public let lastResidual: Scalar?
    public let lastIterate: [Scalar]
    public let failedSupplierWorkUnavailable: Bool
    public let work: NumericalWork
    public var termination: NumericalTermination {
        switch cause {
        case .numerical(let error): error.termination
        case .denseFillLimit: .resourceLimit
        case .equation, .equationMetadataChanged, .invalidEvaluation, .invalidDerivative: .invalidInput
        case .noAcceptableStep, .originalResidualDisagreement: .nonConvergence
        }
    }
}

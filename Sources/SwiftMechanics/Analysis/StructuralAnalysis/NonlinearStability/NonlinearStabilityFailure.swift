public struct NonlinearStabilityFailure: Error, Sendable {
    public enum Cause: Error, Sendable {
        case invalidInput, capacityExceeded, unsupportedDomain, staleSource, outsideDomain
        case branchExceeded, invalidSupplierOutput, invalidSupplierWork, nonFiniteResult, cancelled
        case derivativeMismatch, inertialMismatch, nonPositiveMass, originalResidualRejected
        case ambiguousTangent, noCriticalBracket, unresolvedCriticalPoint, degenerateCriticalPoint
        case force(StaticForceError), equilibrium(EquilibriumError), constraint(ConstraintError)
        case dynamics(DynamicsError), compilation, load(LoadError), numerical(NumericalError)
        case equations(NonlinearCause)
        case nonlinear(NonlinearFailure<Double>), linear(NumericalError), spectral(ComplexSpectrumError)
    }
    public let cause: Cause
    public let work: NumericalWork
    public let failedSupplierWorkUnavailable: Bool
    public let priorAcceptedState: NonlinearStabilityState?
    internal init(_ cause: Cause, work: NumericalWork, prior: NonlinearStabilityState? = nil) {
        self.cause=cause;self.work=work;self.priorAcceptedState=prior
        switch cause {
        case .linear: self.failedSupplierWorkUnavailable=true
        case .nonlinear(let failure): self.failedSupplierWorkUnavailable=failure.failedSupplierWorkUnavailable
        case .equilibrium(let error):
            switch error {
            case .linear(_,let unavailable), .constraintFailure(_,let unavailable): self.failedSupplierWorkUnavailable=unavailable
            case .nonlinear(let failure): self.failedSupplierWorkUnavailable=failure.failedSupplierWorkUnavailable
            default: self.failedSupplierWorkUnavailable=false
            }
        case .invalidSupplierWork: self.failedSupplierWorkUnavailable=true
        default: self.failedSupplierWorkUnavailable=false
        }
    }
}

import MechanicsNumerics
import MechanicsNonlinear
import MechanicsConstraints
import MechanicsDynamics
import MechanicsCompiler
import MechanicsTransmissions
import MechanicsRuntime

public enum MechanismError: Error, Sendable {
    case invalidInput, invalidShape, staleBinding, unsupportedChart, capacityExceeded, cancelled, nonfinite
    case originalConstraint(row: UInt64, residual: Double)
    case originalMomentum(residual: Double)
    case invalidRankEvidence, supplierLedgerReplaced
    case unsupportedTopologyReplacement, unsupportedReactionFidelity, unsupportedSleepExecution
    case numerical(NumericalError, failedSupplierWorkUnavailable: Bool)
    case constraint(ConstraintError)
    case dynamics(DynamicsError)
    case compilation(CompilationFailure)
    case transmission(TransmissionError)
    case runtime(RuntimeFailure)
    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .supplierLedgerReplaced: true
        case .numerical(_, let missing): missing
        case .constraint(let error):
            switch error { case .linear(_,let missing): missing; case .nonlinear(let failure): failure.failedSupplierWorkUnavailable; default: false }
        case .dynamics(let error):
            switch error { case .numerical(_,let missing): missing; default: false }
        case .runtime(let error): error.failedSupplierWorkUnavailable
        case .transmission(let error): error.failedSupplierWorkUnavailable
        default: false
        }
    }
}

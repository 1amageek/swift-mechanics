import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsConstraints
import MechanicsDynamics

public enum DerivativeError: Error, Sendable {
    case invalidInput
    case invalidShape
    case staleBinding
    case derivativeUnavailable
    case capacityExceeded
    case nonFiniteResult
    case cancelled
    case primalMismatch
    case unexpectedSupplierFailure
    case invalidSupplierLedger(failedSupplierWorkUnavailable: Bool)
    case callbackFailure
    case callbackMetadataChanged
    case originalResidualRejected(value: Double, threshold: Double)
    case core(CoreError)
    case model(ModelError)
    case numerical(NumericalError)
    case joints(JointError, failedSupplierWorkUnavailable: Bool)
    case constraints(ConstraintError, failedSupplierWorkUnavailable: Bool)
    case dynamics(DynamicsError, failedSupplierWorkUnavailable: Bool)
}

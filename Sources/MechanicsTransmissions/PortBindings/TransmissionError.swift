import MechanicsCore
import MechanicsNumerics
import MechanicsConstraints
import MechanicsNonlinear

public enum TransmissionError: Error, Sendable {
    case invalidInput, invalidDimensions, staleBinding, frameMismatch, incompatibleGeometry, unsupportedFidelity, outsideDomain
    case nonFiniteResult, capacityExceeded, cancelled, staleContinuation
    case originalResidual(rowID: UInt64, value: Double)
    case powerResidual(value: Double)
    case numerical(NumericalError)
    case core(CoreError)
    case constraint(ConstraintError)
    case assembly(ConstraintError, failedSupplierWorkUnavailable: Bool)

    /// Indicates missing nested work; retained outer work is not necessarily a total.
    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .assembly(_,let unavailable): return unavailable
        case .constraint(.nonlinear(let failure)): return failure.failedSupplierWorkUnavailable
        case .constraint(.linear(_,let unavailable)): return unavailable
        default: return false
        }
    }
}

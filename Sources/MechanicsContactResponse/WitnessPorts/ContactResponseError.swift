import MechanicsCore
import MechanicsJoints
import MechanicsDynamics
import MechanicsNumerics
import MechanicsContactLaws
import MechanicsComplementarity
public enum ContactResponseError: Error, Equatable, Sendable {
    case invalidInput, capacityExceeded, staleCollision, staleModel, staleHistory, frameMismatch, stalePose
    case invalidWitness, ineligiblePair, unsupportedLaw, unsupportedRepresentation, invalidSupplierOutput, nonFiniteResult, cancelled
    case originalResidual(phase: ContactResidualPhase, value: Double, threshold: Double)
    case core(CoreError), joints(JointError), dynamics(DynamicsError), law(ContactLawError), numerical(NumericalError)
    case complementarity(ComplementarityError, failedSupplierWorkUnavailable: Bool)
}

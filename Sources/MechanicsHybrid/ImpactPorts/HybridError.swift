import MechanicsCore
import MechanicsCompiler
import MechanicsJoints
import MechanicsNumerics
import MechanicsDynamics
import MechanicsCollision
import MechanicsContactLaws
import MechanicsRuntime
import MechanicsIntegration

public enum HybridError: Error, Sendable {
    case invalidOwnerAccess, invalidInput, capacityExceeded, staleModel, staleGeometry, invalidWitness, stalePose
    case unsupportedDomain, coupledModes, nonFinite, residualRejected, noDirectedBracket, grazing, chatter, cancelled
    case invalidContinuation, concurrentMutation
    case trajectory(IntegrationFailure)
    case core(CoreError), compiler(CompilationFailure), joints(JointError), numerical(NumericalError)
    case dynamics(DynamicsError), collision(CollisionError), contact(ContactLawError), runtime(RuntimeFailure)
    public var failedSupplierWorkUnavailable: Bool {
        if case .dynamics(.numerical(_, let unavailable)) = self { return unavailable }
        return false
    }
}

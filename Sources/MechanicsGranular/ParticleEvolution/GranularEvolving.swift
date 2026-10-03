import MechanicsCore
import MechanicsNumerics
import MechanicsCollision
import MechanicsContactLaws
public protocol GranularEvolving: Sendable {
    func step(accepted: GranularState, timeStepSeconds: Double, gravity: Vector3, policy: GranularPolicy,
        workspace: inout GranularWorkspace, numericalWork: inout NumericalWork, collisionWork: inout CollisionWork,
        contactWork: inout ContactWork, supplierWork: inout GranularSupplierWork) throws(GranularError) -> GranularStepResult
}

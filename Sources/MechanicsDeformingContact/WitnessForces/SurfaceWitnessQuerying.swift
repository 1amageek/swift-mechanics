import MechanicsModel
import MechanicsNumerics
import MechanicsCollision
public protocol SurfaceWitnessQuerying: Sendable {
    func plane(_ snapshot: DeformingSurfaceSnapshot, face: SurfaceFeatureID, obstacle: CollisionProxy, obstacleBody: ModelReference,
               policy: DeformingContactPolicy, collisionPolicy: CollisionQueryPolicy, work: inout NumericalWork,
               collisionWork: inout CollisionWork) throws(DeformingContactError) -> SurfaceContactWitness
    func selfContact(_ snapshot: DeformingSurfaceSnapshot, first: SurfaceFeatureID, vertex: Int, second: SurfaceFeatureID,
                     policy: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) -> SurfaceContactWitness
}

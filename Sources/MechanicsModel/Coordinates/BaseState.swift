import MechanicsCore

public enum BaseState: Equatable, Sendable {
    case fixed
    case planar(pose: PlanarPose, worldVelocityX: Double, worldVelocityY: Double, angularVelocityZ: Double)
    case spatial(pose: RigidTransform, worldLinearVelocity: Vector3, bodyAngularVelocity: Vector3)
}

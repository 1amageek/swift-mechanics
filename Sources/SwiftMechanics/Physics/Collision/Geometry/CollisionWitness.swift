
public struct CollisionWitness: Sendable {
    public let pair: CollisionPairIdentity
    public let poseA: RigidTransform
    public let poseB: RigidTransform
    public let pointA: Vector3
    public let pointB: Vector3
    public let normal: Vector3
    public let separation: Double
    public let featureA: CollisionFeature
    public let featureB: CollisionFeature
    public let degeneracy: CollisionDegeneracy
    public let approximationError: Double
    public let originalBalanceResidual: Double
}

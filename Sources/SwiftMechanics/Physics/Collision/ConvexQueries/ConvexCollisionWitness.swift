/// Owned numerical certificate, qualified only for the admitted support-map domain.
public struct ConvexCollisionWitness: Sendable {
    public let pair: ConvexPairIdentity
    public let poseA: RigidTransform
    public let poseB: RigidTransform
    public let pointA: Vector3
    public let pointB: Vector3
    public let normal: Vector3
    public let separation: Double
    public let supports: [ConvexSupportWeight]
    public let degeneracy: ConvexWitnessDegeneracy
    public let approximationError: Double
    public let originalBalanceResidual: Double
    public let simplexResidual: Double
    public let supportIntervalResidual: Double
    public let separationLowerBound: Double
    public let separationUpperBound: Double
    public let iterations: Int
}

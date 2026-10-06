public struct RollingEvaluation: Sendable {
    public let modelStamp: ModelStamp
    public let sourceID: String
    public let sourceRevision: UInt64
    public let referenceTime: Double
    public let time: Double
    public let worldFrame: EntityID
    public let wheel: RollingWheel
    public let plane: RollingPlaneBinding
    public let prescribedPlaneSourceID: String?
    public let prescribedPlaneSourceRevision: UInt64?
    public let wheelFrameMotionWorld: FrameMotion
    public let planeFrameMotionWorld: FrameMotion
    public let contactPointWorld: Vector3
    public let contactTraceVelocityWorld: Vector3
    public let wheelContactPointLocal: Vector3
    public let planeContactPointLocal: Vector3
    public let axisWorld: Vector3
    public let planeNormalWorld: Vector3
    public let normalGap: Double
    public let contactChartSine: Double
    public let relativeMaterialVelocityWorld: Vector3
    public let wheelMaterialVelocityWorld: Vector3
    public let planeMaterialVelocityWorld: Vector3
    public let relativeMaterialVelocityRateWorld: Vector3
    public let rows: [RollingConstraintRow]
    public let rank: RollingRankEvidence
}

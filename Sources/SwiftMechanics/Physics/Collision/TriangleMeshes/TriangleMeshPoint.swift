public struct TriangleMeshPoint: Sendable {
    public let geometry: TriangleMeshIdentity
    public let pose: RigidTransform
    public let boundaryPoint: Vector3
    public let normal: Vector3
    public let distance: Double
    public let faceID: UInt64
    public let feature: TriangleMeshFeature
    public let barycentricWeights: Vector3
    public let numericalTieCount: Int
    public let usesFaceNormalAtBoundary: Bool
    public let originalBalanceResidual: Double
}

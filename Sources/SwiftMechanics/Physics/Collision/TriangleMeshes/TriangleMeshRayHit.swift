public struct TriangleMeshRayHit: Sendable {
    public let geometry: TriangleMeshIdentity
    public let pose: RigidTransform
    public let point: Vector3
    public let distance: Double
    public let orientedFaceNormal: Vector3
    public let faceID: UInt64
    public let feature: TriangleMeshFeature
    public let barycentricWeights: Vector3
    public let numericalTieCount: Int
    public let originalResidual: Double
}

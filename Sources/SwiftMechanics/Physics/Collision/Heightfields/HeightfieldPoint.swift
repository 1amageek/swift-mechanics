public struct HeightfieldPoint: Sendable {
    public let geometry: HeightfieldIdentity
    public let pose: RigidTransform
    public let query: Vector3
    public let boundaryPoint: Vector3
    public let unsignedDistance: Double
    public let normal: Vector3
    public let surfaceNormal: Vector3
    public let normalConvention: HeightfieldNormalConvention
    public let face: HeightfieldFace
    public let feature: HeightfieldFeature
    public let barycentric: HeightfieldBarycentric
    public let exactDistanceTieCount: Int
    public let originalResidual: Double
}

public struct TriangleMeshSphereContact: Sendable {
    public let sphereGeometry: CollisionGeometryIdentity
    public let spherePose: RigidTransform
    public let meshPoint: TriangleMeshPoint
    public let spherePoint: Vector3
    public let normalFromSphereToMesh: Vector3
    public let separation: Double
    public let approximationError: Double
    public let originalBalanceResidual: Double
}

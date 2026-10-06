public struct TriangleMeshSphereTOI: Sendable {
    public let lowerTime: Double
    public let upperTime: Double
    public let lowerSeparation: Double
    public let upperContact: TriangleMeshSphereContact
    public let initialOverlap: Bool
    public let iterations: Int
}

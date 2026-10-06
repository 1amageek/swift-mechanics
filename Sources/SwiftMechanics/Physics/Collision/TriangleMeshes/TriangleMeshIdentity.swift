public struct TriangleMeshIdentity: Equatable, Sendable {
    public let colliderID: EntityID
    public let bodyID: EntityID
    public let frameID: EntityID
    public let geometryRevision: UInt64
    public let frameRevision: UInt64
    public let representation: GeometryRepresentation
    public let vertices: [Vector3]
    public let faces: [TriangleMeshFace]
    public let distancePolicy: TriangleMeshDistancePolicy

    public var approximationError: Double {
        switch representation.quality {
        case .exact: 0
        case .approximation(let maximumDeviationMeters): maximumDeviationMeters
        }
    }
}

public struct ConvexGeometryIdentity: Equatable, Sendable {
    public let colliderID: EntityID
    public let bodyID: EntityID
    public let frameID: EntityID
    public let geometryRevision: UInt64
    public let frameRevision: UInt64
    public let shape: ConvexShape
    public let margin: Double
    public let representation: GeometryRepresentation
    public let resolution: CollisionResolution

    public var approximationError: Double {
        switch representation.quality {
        case .exact: 0
        case .approximation(let maximumDeviationMeters): maximumDeviationMeters
        }
    }
}

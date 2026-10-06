public struct HeightfieldIdentity: Equatable, Sendable {
    public let reference: HeightfieldReference
    public let bodyID: EntityID
    public let rows: Int
    public let columns: Int
    public let spacingX: Double
    public let spacingY: Double
    public let origin: Vector3
    public let heights: [Double]
    public let diagonal: HeightfieldDiagonal
    public let representation: GeometryRepresentation
    public let motion: HeightfieldMotion

    public var approximationError: Double {
        switch representation.quality {
        case .exact: 0
        case .approximation(let maximumDeviationMeters): maximumDeviationMeters
        }
    }
}

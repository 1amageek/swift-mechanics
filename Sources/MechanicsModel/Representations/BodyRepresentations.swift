public struct BodyRepresentations: Equatable, Sendable {
    public let geometricShape: GeometryRepresentation?
    public let displayGeometry: GeometryRepresentation?
    public let collisionGeometry: GeometryRepresentation?

    public init(geometricShape: GeometryRepresentation? = nil,
                displayGeometry: GeometryRepresentation? = nil,
                collisionGeometry: GeometryRepresentation? = nil) throws(ModelError) {
        guard geometricShape == nil || geometricShape?.kind == .geometricShape,
              displayGeometry == nil || displayGeometry?.kind == .displayGeometry,
              collisionGeometry == nil || collisionGeometry?.kind == .collisionGeometry else {
            throw .representationKindMismatch
        }
        self.geometricShape = geometricShape
        self.displayGeometry = displayGeometry
        self.collisionGeometry = collisionGeometry
    }

    public func requiring(_ kind: RepresentationKind) throws(ModelError) -> GeometryRepresentation {
        let representation: GeometryRepresentation?
        switch kind {
        case .geometricShape: representation = geometricShape
        case .displayGeometry: representation = displayGeometry
        case .collisionGeometry: representation = collisionGeometry
        }
        guard let representation else { throw .missingRepresentation }
        return representation
    }
}

public enum GeometryParameterTarget: Equatable, Sendable {
    case fixedRoot(body: EntityID, frame: EntityID)
    case fixedAnchor(joint: EntityID, frame: EntityID)
    case jointAxis(joint: EntityID, index: Int)
    case topology(entity: EntityID)
}

/// Caller-issued numeric coordinate identity and SI scale/domain, bound to an absolute joint ID.
public struct StructuralCoordinateBinding: Sendable {
    public let joint: EntityID
    public let coordinateID: UInt64
    public let scale: Double
    public let minimumPosition: Double
    public let maximumPosition: Double
    public init(joint: EntityID, coordinateID: UInt64, scale: Double,
                minimumPosition: Double, maximumPosition: Double) throws(StructuralSystemFailure) {
        guard joint.kind == .joint, scale.isFinite, scale > 0, minimumPosition.isFinite,
              maximumPosition.isFinite, minimumPosition <= maximumPosition else { throw .invalidBinding(joint) }
        self.joint = joint; self.coordinateID = coordinateID; self.scale = scale
        self.minimumPosition = minimumPosition; self.maximumPosition = maximumPosition
    }
}

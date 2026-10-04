public struct BodyWrenchEvidence: Equatable, Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let referencePoint: Vector3
    public let wrench: SpatialWrench
    internal init(body: EntityID, frame: EntityID, referencePoint: Vector3, wrench: SpatialWrench) {
        self.body = body; self.frame = frame; self.referencePoint = referencePoint; self.wrench = wrench
    }
}

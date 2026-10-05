/// World-expressed physical force/torque about the declared current body origin.
public struct TaskSpaceWrench: Sendable {
    public let body: EntityID
    public let referencePointWorld: Vector3
    public let wrench: SpatialWrench
    public init(body: EntityID, referencePointWorld: Vector3, wrench: SpatialWrench) {
        self.body = body; self.referencePointWorld = referencePointWorld; self.wrench = wrench
    }
}

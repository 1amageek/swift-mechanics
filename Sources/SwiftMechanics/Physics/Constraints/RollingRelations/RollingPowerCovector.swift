/// Force direction paired with a world geometric twist at the physical contact point.
public struct RollingPowerCovector: Equatable, Sendable {
    /// nil denotes the externally prescribed plane, which has no generalized-coordinate columns.
    public let body: EntityID?
    public let frame: EntityID
    public let worldFrame: EntityID
    public let pointWorld: Vector3
    /// Dimensionless linear pairing direction; a multiplier in N gives a force.
    public let linearDirection: Vector3
    /// Pure couple about pointWorld, in metres per unit row force; zero for ideal point contact.
    public let angularDirection: Vector3

    internal init(body: EntityID?, frame: EntityID, worldFrame: EntityID,
                  pointWorld: Vector3, direction: Vector3) {
        self.body = body; self.frame = frame; self.worldFrame = worldFrame
        self.pointWorld = pointWorld; linearDirection = direction; angularDirection = .zero
    }
}

import MechanicsModel

public struct JointCoordinateLayout: Equatable, Sendable {
    public let joint: EntityID
    public let positions: CoordinateRange
    public let velocities: CoordinateRange

    internal init(joint: EntityID, positions: CoordinateRange, velocities: CoordinateRange) {
        self.joint = joint; self.positions = positions; self.velocities = velocities
    }
}

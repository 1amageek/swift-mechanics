import MechanicsModel

public struct TreeCoordinateLayout: Equatable, Sendable {
    public let bodyOrder: [EntityID]
    public let joints: [JointCoordinateLayout]
    public let positionCount: Int
    public let velocityCount: Int

    internal init(bodyOrder: [EntityID], joints: [JointCoordinateLayout], positionCount: Int, velocityCount: Int) {
        self.bodyOrder = bodyOrder; self.joints = joints
        self.positionCount = positionCount; self.velocityCount = velocityCount
    }
}

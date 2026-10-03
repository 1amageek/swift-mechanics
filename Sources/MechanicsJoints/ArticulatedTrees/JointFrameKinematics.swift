import MechanicsModel

public struct JointFrameKinematics: Equatable, Sendable {
    public let joint: EntityID
    public let parentAnchor: FrameKinematics
    public let childAnchor: FrameKinematics
    public let relative: JointKinematics

    internal init(joint: EntityID, parentAnchor: FrameKinematics, childAnchor: FrameKinematics, relative: JointKinematics) {
        self.joint = joint; self.parentAnchor = parentAnchor; self.childAnchor = childAnchor; self.relative = relative
    }
}

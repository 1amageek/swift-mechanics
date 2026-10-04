public struct SubtreeJointMapping: Equatable, Sendable {
    public let joint: EntityID
    public let source: JointCoordinateLayout
    public let target: JointCoordinateLayout
    internal init(source: JointCoordinateLayout, target: JointCoordinateLayout) {
        joint = source.joint; self.source = source; self.target = target
    }
}

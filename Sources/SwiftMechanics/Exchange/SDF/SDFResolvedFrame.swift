/// Dynamic attachment is independent of the coordinates used for the original initial pose.
public struct SDFResolvedFrame: Sendable {
    public let scopedName: String
    public let originalNode: Int
    public let initialWorldPose: RigidTransform
    public let attachedBody: EntityID?
    public let assemblyIndex: Int?
    public let placementInAttachedBody: RigidTransform
}

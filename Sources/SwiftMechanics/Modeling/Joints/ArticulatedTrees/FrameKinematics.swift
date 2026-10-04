
public struct FrameKinematics: Equatable, Sendable {
    public let frame: EntityID
    public let referenceFrame: EntityID
    public let motion: FrameMotion

    internal init(frame: EntityID, referenceFrame: EntityID, motion: FrameMotion) {
        self.frame = frame; self.referenceFrame = referenceFrame; self.motion = motion
    }
}

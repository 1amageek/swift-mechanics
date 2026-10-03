import MechanicsModel

public struct PrescribedAnchorState: Equatable, Sendable {
    public let frame: EntityID
    public let time: Double
    public let motion: FrameMotion

    public init(frame: EntityID, time: Double, motion: FrameMotion) throws(JointError) {
        guard frame.kind == .frame else { throw .identityKindMismatch }
        guard time.isFinite else { throw .nonFiniteState }
        self.frame = frame; self.time = time; self.motion = motion
    }
}

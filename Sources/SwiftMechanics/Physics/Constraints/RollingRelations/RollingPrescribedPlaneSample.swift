/// Instantaneous complete geometric jet. Its caller owns the prescribed law's correctness.
public struct RollingPrescribedPlaneSample: Sendable {
    public let sourceID: String
    public let sourceRevision: UInt64
    public let modelStamp: ModelStamp
    public let frame: EntityID
    public let worldFrame: EntityID
    public let time: Double
    public let motion: FrameMotion

    public init(sourceID: String, sourceRevision: UInt64, modelStamp: ModelStamp, frame: EntityID,
                worldFrame: EntityID, time: Double, motion: FrameMotion) throws(RollingError) {
        guard !sourceID.isEmpty, frame.kind == .frame, worldFrame.kind == .frame,
              frame != worldFrame, time.isFinite else { throw .invalidInput }
        self.sourceID = sourceID; self.sourceRevision = sourceRevision; self.modelStamp = modelStamp
        self.frame = frame; self.worldFrame = worldFrame; self.time = time; self.motion = motion
    }
}

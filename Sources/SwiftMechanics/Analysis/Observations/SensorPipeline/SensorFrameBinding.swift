public struct SensorFrameBinding: Sendable {
    public let channelIndex: Int
    public let body: EntityID
    public let frame: EntityID
    public let velocityConvention: JointEncoderObservation.VelocityConvention?
    internal init(channel: Int, body: EntityID, frame: EntityID, convention: JointEncoderObservation.VelocityConvention?) {
        channelIndex = channel; self.body = body; self.frame = frame; velocityConvention = convention
    }
}

public final class SensorPhysicalSource: Sendable {
    public let model: ModelStamp
    public let physical: KinematicState
    public let acceptedSequence: UInt64
    public let frames: [SensorFrameBinding]
    internal let encoded: [UInt8]
    internal init(model: ModelStamp, physical: KinematicState, sequence: UInt64, frames: [SensorFrameBinding], encoded: [UInt8]) {
        self.model = model; self.physical = physical; acceptedSequence = sequence; self.frames = frames; self.encoded = encoded
    }
}

public final class SurfaceContactState: Sendable {
    public let sample: DeformingSurfaceSnapshot
    public let acceptedTime: Double
    public let histories: [ContactHistory]
    public let generation: UInt64
    internal init(sample: DeformingSurfaceSnapshot, time: Double, histories: [ContactHistory], generation: UInt64) {
        self.sample=sample; acceptedTime=time; self.histories=histories; self.generation=generation
    }
}

/// Canonical mathematical source. Compiled root authority remains the consumer's check.
public struct PrescribedBaseMotionSample: Sendable {
    public let metadata: String
    public let layout: BaseLayout
    public let frame: EntityID
    public let worldFrame: EntityID
    public let time: Double
    public let q: [Double]
    public let v: [Double]
    public let a: [Double]
    public let coordinateRate: [Double]
    public let motion: FrameMotion

    internal init(program: PrescribedBaseMotionProgram, time: Double, q: [Double], v: [Double], a: [Double],
                  coordinateRate: [Double], motion: FrameMotion) {
        metadata = program.metadata; layout = program.layout; frame = program.law.frame
        worldFrame = program.law.parentFrame; self.time = time
        self.q = q; self.v = v; self.a = a; self.coordinateRate = coordinateRate; self.motion = motion
    }
}

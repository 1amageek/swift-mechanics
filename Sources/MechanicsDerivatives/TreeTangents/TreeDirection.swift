public struct TreeDirection: Sendable {
    public let revision: UInt64
    public let configuration: [Double]
    public let velocity: [Double]
    public let acceleration: [Double]
    public let screwPitch: [Double]
    public let prescribed: [FrameMotionDirection]
    public let time: Double
    public init(revision: UInt64, configuration: [Double], velocity: [Double], acceleration: [Double],
                screwPitch: [Double], prescribed: [FrameMotionDirection] = [], time: Double = 0) {
        self.revision=revision; self.configuration=configuration; self.velocity=velocity; self.acceleration=acceleration
        self.screwPitch=screwPitch; self.prescribed=prescribed; self.time=time
    }
}

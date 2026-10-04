public struct PrescribedMotionJet: Equatable, Sendable {
    public let displacement:Vector3
    public let angle:Double
    public let linearVelocity:Vector3
    public let angularRate:Double
    public let linearAcceleration:Vector3
    public let angularAcceleration:Double
    public init(displacement:Vector3,angle:Double,linearVelocity:Vector3,angularRate:Double,
                linearAcceleration:Vector3,angularAcceleration:Double) throws(PrescribedMotionError) {
        guard angle.isFinite,angularRate.isFinite,angularAcceleration.isFinite else { throw .invalidInput }
        self.displacement=displacement;self.angle=angle;self.linearVelocity=linearVelocity;self.angularRate=angularRate
        self.linearAcceleration=linearAcceleration;self.angularAcceleration=angularAcceleration
    }
}

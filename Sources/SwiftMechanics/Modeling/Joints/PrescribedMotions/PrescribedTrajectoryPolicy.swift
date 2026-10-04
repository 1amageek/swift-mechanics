public struct PrescribedTrajectoryPolicy: Sendable {
    public let motion:PrescribedMotionPolicy
    public let maximumSegments:Int
    public init(motion:PrescribedMotionPolicy,maximumSegments:Int) throws(PrescribedMotionError) {
        guard maximumSegments > 0 else { throw .invalidInput }
        self.motion=motion;self.maximumSegments=maximumSegments
    }
}

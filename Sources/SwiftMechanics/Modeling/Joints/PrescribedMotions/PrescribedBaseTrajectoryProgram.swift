public struct PrescribedBaseTrajectoryProgram: Sendable {
    public let trajectory:PrescribedTrajectory
    public let layout:BaseLayout
    public let metadata:String
    public let policy:PrescribedTrajectoryPolicy
    public let initialPlanarAngle:Double?
    public var minimumTime:Double { trajectory.minimumTime }
    public var maximumTime:Double { trajectory.maximumTime }
    public init(trajectory:PrescribedTrajectory,layout:BaseLayout,policy:PrescribedTrajectoryPolicy,
                work:inout NumericalWork) throws(PrescribedMotionError) {
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        guard layout != .fixed else { throw .unsupportedChart }
        try PrescribedBaseMotionArithmetic.reserve(128,operations:128,work:&work)
        let angle:Double?
        if layout == .planarFloating {
            try Self.planar(trajectory,policy:policy,work:&work)
            do throws(CoreError) { angle=try trajectory.initialPose.rotation.rotationVector().z }
            catch { throw .mathematical(error) }
        } else { angle=nil }
        let signature=try PrescribedTrajectoryMetadata.encode([trajectory],layout:layout,angle:angle,policy:policy,work:&work)
        self.trajectory=trajectory;self.layout=layout;self.policy=policy;metadata=signature;initialPlanarAngle=angle
    }
    private static func planar(_ t:PrescribedTrajectory,policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) {
        let pose=t.initialPose,axis=t.rotationAxis
        guard pose.translation.z == 0,pose.rotation.x == 0,pose.rotation.y == 0,axis.x == 0,axis.y == 0,abs(axis.z) == 1 else { throw .nonPlanarMotion }
        switch t {
        case .quadratic(let m): guard m.translationRate.z == 0,m.translationAcceleration.z == 0 else { throw .nonPlanarMotion }
        case .harmonic(let m): guard m.translationSine.z == 0,m.translationCosine.z == 0 else { throw .nonPlanarMotion }
        case .piecewise(let m):
            guard m.segments.count <= policy.maximumSegments else { throw .capacityExceeded }
            try PrescribedTrajectoryArithmetic.reserve(count:m.segments.count,scalars:64,operations:16,work:&work)
            for segment in m.segments {
                for jet in [segment.start,segment.end] {
                    guard jet.displacement.z == 0,jet.linearVelocity.z == 0,jet.linearAcceleration.z == 0 else { throw .nonPlanarMotion }
                }
            }
        }
    }
}

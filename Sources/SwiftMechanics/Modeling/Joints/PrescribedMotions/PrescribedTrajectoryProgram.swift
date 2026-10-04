public struct PrescribedTrajectoryProgram: Sendable {
    public let trajectories:[PrescribedTrajectory]
    public let metadata:String
    public let policy:PrescribedTrajectoryPolicy
    public let minimumTime:Double
    public let maximumTime:Double
    public init(trajectories:[PrescribedTrajectory],policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) {
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        guard !trajectories.isEmpty,trajectories.count <= policy.motion.maximumSamples else { throw .capacityExceeded }
        try PrescribedTrajectoryArithmetic.reserve(count:trajectories.count,scalars:128,operations:try PrescribedTrajectoryArithmetic.sum(128,trajectories.count),work:&work)
        let bytes=try PrescribedTrajectoryMetadata.admit(trajectories,policy:policy,work:&work)
        try PrescribedBaseMotionArithmetic.reserve(128,operations:try PrescribedTrajectoryArithmetic.product(bytes,trajectories.count),work:&work)
        var minimum = -Double.greatestFiniteMagnitude,maximum=Double.greatestFiniteMagnitude
        for (i,t) in trajectories.enumerated() {
            guard !trajectories[..<i].contains(where:{$0.frame == t.frame}) else { throw .invalidFrame }
            minimum=max(minimum,t.minimumTime);maximum=min(maximum,t.maximumTime)
        }
        guard minimum <= maximum else { throw .outsideDomain }
        let ordered=trajectories.sorted { $0.frame.key < $1.frame.key }
        let signature=try PrescribedTrajectoryMetadata.encode(ordered,layout:nil,angle:nil,policy:policy,work:&work,admittedBytes:bytes)
        self.trajectories=ordered;metadata=signature;self.policy=policy;minimumTime=minimum;maximumTime=maximum
    }
}

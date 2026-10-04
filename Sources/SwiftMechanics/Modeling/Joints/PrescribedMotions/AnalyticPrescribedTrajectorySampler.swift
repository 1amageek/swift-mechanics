public struct AnalyticPrescribedTrajectorySampler: PrescribedTrajectorySampling {
    public init() {}
    @inline(never)
    public func sample(_ program:PrescribedTrajectoryProgram,time:Double,policy:PrescribedTrajectoryPolicy,
                       work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample {
        try PrescribedTrajectoryAdmission.admit(program.trajectories,metadata:program.metadata,policy:policy,work:&work)
        try PrescribedTrajectoryAdmission.time(time,minimum:program.minimumTime,maximum:program.maximumTime)
        var anchors:[PrescribedAnchorState]=[];anchors.reserveCapacity(program.trajectories.count)
        for trajectory in program.trajectories {
            try PrescribedBaseMotionArithmetic.check(policy.motion)
            let value=try PrescribedTrajectoryEvaluation.value(trajectory,time:time)
            do throws(JointError) { anchors.append(try PrescribedAnchorState(frame:trajectory.frame,time:time,motion:value.motion)) }
            catch { throw .invalidInput }
        }
        try PrescribedBaseMotionArithmetic.check(policy.motion)
        return try PrescribedMotionSample(metadata:program.metadata,time:time,anchors:anchors,policy:policy.motion)
    }
}

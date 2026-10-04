public struct PrescribedTrajectoryBoundaryQuery: PrescribedTrajectoryBoundaryQuerying {
    public init() {}
    public func nextBoundary(_ program:PrescribedTrajectoryProgram,after time:Double,through limit:Double,
                             policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        try PrescribedTrajectoryAdmission.admit(program.trajectories,metadata:program.metadata,policy:policy,work:&work)
        try interval(time,limit,minimum:program.minimumTime,maximum:program.maximumTime)
        var next:Double?
        for trajectory in program.trajectories {
            if let value=knot(trajectory,after:time,through:limit) {
                if let current=next { if value < current { next=value } } else { next=value }
            }
        }
        try PrescribedBaseMotionArithmetic.check(policy.motion);return next
    }
    public func nextBaseBoundary(_ program:PrescribedBaseTrajectoryProgram,after time:Double,through limit:Double,
                                 policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> Double? {
        try PrescribedTrajectoryAdmission.admitBase(program,policy:policy,work:&work)
        try interval(time,limit,minimum:program.minimumTime,maximum:program.maximumTime)
        let next=knot(program.trajectory,after:time,through:limit)
        try PrescribedBaseMotionArithmetic.check(policy.motion);return next
    }
    private func interval(_ time:Double,_ limit:Double,minimum:Double,maximum:Double) throws(PrescribedMotionError) {
        guard time.isFinite,limit.isFinite,time <= limit else { throw .invalidInput }
        guard time >= minimum,limit <= maximum else { throw .outsideDomain }
    }
    private func knot(_ trajectory:PrescribedTrajectory,after time:Double,through limit:Double) -> Double? {
        guard case .piecewise(let m)=trajectory else { return nil }
        var low=1,high=m.segments.count
        while low < high { let middle=low+(high-low)/2;if m.segments[middle].startTime <= time { low=middle+1 } else { high=middle } }
        guard low < m.segments.count,m.segments[low].startTime <= limit else { return nil }
        return m.segments[low].startTime
    }
}

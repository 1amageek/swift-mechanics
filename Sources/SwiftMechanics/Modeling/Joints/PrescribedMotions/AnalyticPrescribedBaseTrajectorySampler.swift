public struct AnalyticPrescribedBaseTrajectorySampler: PrescribedBaseTrajectorySampling {
    public init() {}
    @inline(never)
    public func sampleBase(_ program:PrescribedBaseTrajectoryProgram,time:Double,policy:PrescribedTrajectoryPolicy,
                           work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        try PrescribedTrajectoryAdmission.admitBase(program,policy:policy,work:&work)
        try PrescribedTrajectoryAdmission.time(time,minimum:program.minimumTime,maximum:program.maximumTime)
        let value=try PrescribedTrajectoryEvaluation.value(program.trajectory,time:time),angle:Double?
        if program.layout == .planarFloating {
            guard let initial=program.initialPlanarAngle else { throw .staleSource }
            angle=try PrescribedTrajectoryArithmetic.finite(initial+program.trajectory.rotationAxis.z*value.angle)
        } else { angle=nil }
        let result=try PrescribedBaseCoordinates.make(layout:program.layout,metadata:program.metadata,frame:program.trajectory.frame,
            worldFrame:program.trajectory.parentFrame,time:time,planarAngle:angle,motion:value.motion)
        try PrescribedBaseMotionArithmetic.check(policy.motion);return result
    }
}

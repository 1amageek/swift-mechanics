public protocol PrescribedBaseTrajectorySampling: Sendable {
    func sampleBase(_ program:PrescribedBaseTrajectoryProgram,time:Double,policy:PrescribedTrajectoryPolicy,
                    work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample
}

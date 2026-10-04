public protocol PrescribedTrajectorySampling: Sendable {
    func sample(_ program:PrescribedTrajectoryProgram,time:Double,policy:PrescribedTrajectoryPolicy,
                work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample
}

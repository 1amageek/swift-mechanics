public protocol PrescribedTrajectoryBoundaryQuerying: Sendable {
    func nextBoundary(_ program:PrescribedTrajectoryProgram,after time:Double,through limit:Double,
                      policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> Double?
    func nextBaseBoundary(_ program:PrescribedBaseTrajectoryProgram,after time:Double,through limit:Double,
                          policy:PrescribedTrajectoryPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> Double?
}

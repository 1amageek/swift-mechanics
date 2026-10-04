public protocol PrescribedMotionSampling: Sendable {
    func sample(_ program:PrescribedMotionProgram,time:Double,policy:PrescribedMotionPolicy,
                work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample
}

public protocol PrescribedBaseMotionSampling: Sendable {
    func sampleBase(_ program: PrescribedBaseMotionProgram, time: Double, policy: PrescribedMotionPolicy,
                    work: inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample
}

public struct AnalyticPrescribedBaseMotionSampler: PrescribedBaseMotionSampling {
    public init() {}
    @inline(never)
    public func sampleBase(_ program: PrescribedBaseMotionProgram, time: Double, policy: PrescribedMotionPolicy,
                           work: inout NumericalWork) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        try PrescribedBaseMotionArithmetic.admit(program, policy: policy)
        guard time.isFinite else { throw .invalidInput }
        let operations: Int
        do throws(NumericalError) { operations = try NumericalWork.sum(1024, program.metadata.utf8.count) }
        catch { throw .numerical(error) }
        try PrescribedBaseMotionArithmetic.reserve(256, operations: operations, work: &work)
        let motion = try AnalyticMotionEvaluation.motion(program.law, time: time)
        let angle: Double?
        if program.layout == .planarFloating {
            guard let initial = program.initialPlanarAngle else { throw .staleSource }
            let dt = time - program.law.referenceTime
            let value = initial + program.law.rotationAxis.z *
                (program.law.angularRate * dt + 0.5 * program.law.angularAcceleration * dt * dt)
            guard value.isFinite else { throw .invalidInput }
            angle = value
        } else { angle = nil }
        let value = try PrescribedBaseCoordinates.make(layout: program.layout, metadata: program.metadata,
            frame: program.law.frame, worldFrame: program.law.parentFrame, time: time, planarAngle: angle, motion: motion)
        try PrescribedBaseMotionArithmetic.check(policy)
        return value
    }
}

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
        let value = try coordinates(program, time: time, motion: motion)
        try PrescribedBaseMotionArithmetic.check(policy)
        return value
    }
    @inline(never)
    private func coordinates(_ program: PrescribedBaseMotionProgram, time: Double,
                             motion: FrameMotion) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        let q: [Double], v: [Double], a: [Double], rate: [Double]
        switch program.layout {
        case .fixed: throw .unsupportedChart
        case .planarFloating:
            guard let initial = program.initialPlanarAngle else { throw .staleSource }
            let dt = time - program.law.referenceTime
            let angle = initial + program.law.rotationAxis.z *
                (program.law.angularRate * dt + 0.5 * program.law.angularAcceleration * dt * dt)
            guard angle.isFinite else { throw .invalidInput }
            let pose: PlanarPose
            do throws(ModelError) { pose = try PlanarPose(x: motion.pose.translation.x, y: motion.pose.translation.y, angle: angle) }
            catch { throw .invalidInput }
            let encoded: BaseCoordinates
            do { encoded = try program.layout.encode(.planar(pose: pose, worldVelocityX: motion.velocity.linear.x,
                worldVelocityY: motion.velocity.linear.y, angularVelocityZ: motion.velocity.angular.z)) }
            catch { throw .invalidInput }
            q = encoded.q; v = encoded.v
            a = [motion.acceleration.linear.x, motion.acceleration.linear.y, motion.acceleration.angular.z]
            rate = v
        case .spatialFloating:
            let angular: Vector3, alpha: Vector3, quaternionRate: QuaternionRate
            do throws(CoreError) {
                let inverse = motion.pose.rotation.conjugated()
                angular = try inverse.rotating(motion.velocity.angular)
                // d(R^-1 omega)/dt = R^-1 alpha - omegaBody cross omegaBody.
                alpha = try inverse.rotating(motion.acceleration.angular)
                quaternionRate = try motion.pose.rotation.bodyRate(for: angular)
            } catch { throw .mathematical(error) }
            let encoded: BaseCoordinates
            do { encoded = try program.layout.encode(.spatial(pose: motion.pose,
                worldLinearVelocity: motion.velocity.linear, bodyAngularVelocity: angular)) }
            catch { throw .invalidInput }
            q = encoded.q; v = encoded.v
            a = [motion.acceleration.linear.x, motion.acceleration.linear.y, motion.acceleration.linear.z, alpha.x, alpha.y, alpha.z]
            rate = [motion.velocity.linear.x, motion.velocity.linear.y, motion.velocity.linear.z,
                quaternionRate.w, quaternionRate.x, quaternionRate.y, quaternionRate.z]
        }
        return PrescribedBaseMotionSample(program: program, time: time, q: q, v: v, a: a, coordinateRate: rate, motion: motion)
    }
}

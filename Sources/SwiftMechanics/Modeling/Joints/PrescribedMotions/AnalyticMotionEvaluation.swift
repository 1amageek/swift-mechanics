/// Shared original law mathematics; callers own admission, work and publication.
internal enum AnalyticMotionEvaluation {
    @inline(never)
    static func motion(_ law: AnalyticPrescribedMotion, time: Double) throws(PrescribedMotionError) -> FrameMotion {
        guard time.isFinite else { throw .invalidInput }
        guard time >= law.minimumTime, time <= law.maximumTime else { throw .outsideDomain }
        let dt = time - law.referenceTime
        let angle = try self.angle(law, delta: dt)
        let rate = law.angularRate + law.angularAcceleration * dt
        guard dt.isFinite, angle.isFinite, rate.isFinite else { throw .invalidInput }
        do throws(CoreError) {
            let translation = try law.initialPose.translation.adding(law.translationRate.scaled(by: dt))
                .adding(law.translationAcceleration.scaled(by: 0.5 * dt * dt))
            let rotation = dt == 0 ? law.initialPose.rotation :
                try UnitQuaternion(axis: law.rotationAxis, angle: angle).multiplied(by: law.initialPose.rotation)
            return FrameMotion(pose: dt == 0 ? law.initialPose : RigidTransform(rotation: rotation, translation: translation),
                velocity: SpatialMotion(angular: try law.rotationAxis.scaled(by: rate),
                    linear: try law.translationRate.adding(law.translationAcceleration.scaled(by: dt))),
                acceleration: SpatialMotion(angular: try law.rotationAxis.scaled(by: law.angularAcceleration),
                    linear: law.translationAcceleration))
        } catch { throw .mathematical(error) }
    }
    static func angle(_ law:AnalyticPrescribedMotion,delta:Double) throws(PrescribedMotionError) -> Double {
        try PrescribedTrajectoryArithmetic.finite(law.angularRate*delta+0.5*law.angularAcceleration*delta*delta)
    }
}

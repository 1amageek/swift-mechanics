public struct AnalyticPrescribedMotionSampler: PrescribedMotionSampling {
    public init() {}
    public func sample(_ program:PrescribedMotionProgram,time:Double,policy:PrescribedMotionPolicy,
                       work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample {
        guard program.motions.count <= policy.maximumSamples,program.metadata.utf8.count <= policy.maximumMetadataBytes else { throw .capacityExceeded }
        if policy.isCancelled() { throw .cancelled }
        guard time.isFinite else { throw .invalidInput }
        do throws(NumericalError) { try work.requireStorage(try NumericalWork.product(128,program.motions.count));try work.chargeOperations(try NumericalWork.sum(program.metadata.utf8.count,try NumericalWork.product(512,program.motions.count))) }
        catch { throw .numerical(error) }
        var anchors:[PrescribedAnchorState]=[];anchors.reserveCapacity(program.motions.count)
        for m in program.motions {
            guard m.frame.key.utf8.count <= policy.maximumIdentifierBytes,m.parentFrame.key.utf8.count <= policy.maximumIdentifierBytes else { throw .capacityExceeded }
            guard time >= m.minimumTime,time <= m.maximumTime else { throw .outsideDomain }
            let dt=time-m.referenceTime,angle=m.angularRate*dt+0.5*m.angularAcceleration*dt*dt,rate=m.angularRate+m.angularAcceleration*dt
            guard dt.isFinite,angle.isFinite,rate.isFinite else { throw .invalidInput }
            let motion:FrameMotion
            do throws(CoreError) {
                let translation=try m.initialPose.translation.adding(m.translationRate.scaled(by:dt)).adding(m.translationAcceleration.scaled(by:0.5*dt*dt))
                let rotation=dt == 0 ? m.initialPose.rotation : try UnitQuaternion(axis:m.rotationAxis,angle:angle).multiplied(by:m.initialPose.rotation)
                motion=FrameMotion(pose:dt == 0 ? m.initialPose : RigidTransform(rotation:rotation,translation:translation),
                    velocity:SpatialMotion(angular:try m.rotationAxis.scaled(by:rate),linear:try m.translationRate.adding(m.translationAcceleration.scaled(by:dt))),
                    acceleration:SpatialMotion(angular:try m.rotationAxis.scaled(by:m.angularAcceleration),linear:m.translationAcceleration))
            } catch { throw .mathematical(error) }
            do throws(JointError) { anchors.append(try PrescribedAnchorState(frame:m.frame,time:time,motion:motion)) }
            catch { throw .invalidInput }
        }
        if policy.isCancelled() { throw .cancelled }
        return try PrescribedMotionSample(metadata:program.metadata,time:time,anchors:anchors,policy:policy)
    }
}

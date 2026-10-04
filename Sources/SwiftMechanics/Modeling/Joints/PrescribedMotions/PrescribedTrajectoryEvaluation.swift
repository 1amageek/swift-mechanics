internal enum PrescribedTrajectoryEvaluation {
    @inline(never)
    static func value(_ trajectory:PrescribedTrajectory,time:Double) throws(PrescribedMotionError) -> (motion:FrameMotion,angle:Double) {
        guard time.isFinite else { throw .invalidInput }
        guard time >= trajectory.minimumTime,time <= trajectory.maximumTime else { throw .outsideDomain }
        if case .quadratic(let m)=trajectory {
            return (try AnalyticMotionEvaluation.motion(m,time:time),try AnalyticMotionEvaluation.angle(m,delta:time-m.referenceTime))
        }
        let jet:PrescribedMotionJet
        switch trajectory {
        case .quadratic: throw .invalidInput
        case .harmonic(let m): jet=try harmonic(m,time:time)
        case .piecewise(let m): jet=try piecewise(m,time:time)
        }
        do throws(CoreError) {
            let rotation=time == trajectory.referenceTime ? trajectory.initialPose.rotation :
                try UnitQuaternion(axis:trajectory.rotationAxis,angle:jet.angle).multiplied(by:trajectory.initialPose.rotation)
            let pose=time == trajectory.referenceTime ? trajectory.initialPose :
                RigidTransform(rotation:rotation,translation:try trajectory.initialPose.translation.adding(jet.displacement))
            return (FrameMotion(pose:pose,velocity:SpatialMotion(angular:try trajectory.rotationAxis.scaled(by:jet.angularRate),linear:jet.linearVelocity),
                acceleration:SpatialMotion(angular:try trajectory.rotationAxis.scaled(by:jet.angularAcceleration),linear:jet.linearAcceleration)),jet.angle)
        } catch { throw .mathematical(error) }
    }
    private static func harmonic(_ m:HarmonicPrescribedMotion,time:Double) throws(PrescribedMotionError) -> PrescribedMotionJet {
        let dt=try PrescribedTrajectoryArithmetic.finite(time-m.referenceTime)
        let x=try PrescribedTrajectoryArithmetic.finite(m.phase+m.frequency*dt)
        let sine=PrescribedTrajectoryTrigonometry.sine(x),cosine=PrescribedTrajectoryTrigonometry.cosine(x)
        let ds=sine-PrescribedTrajectoryTrigonometry.sine(m.phase),dc=cosine-PrescribedTrajectoryTrigonometry.cosine(m.phase)
        let displacement:Vector3,velocity:Vector3,acceleration:Vector3
        do throws(CoreError) {
            displacement=try m.translationSine.scaled(by:ds).adding(m.translationCosine.scaled(by:dc))
            velocity=try m.translationSine.scaled(by:cosine).subtracting(m.translationCosine.scaled(by:sine)).scaled(by:m.frequency)
            acceleration=try m.translationSine.scaled(by:sine).adding(m.translationCosine.scaled(by:cosine)).scaled(by:-m.frequency*m.frequency)
        } catch { throw .mathematical(error) }
        return try PrescribedMotionJet(displacement:displacement,angle:m.angularSine*ds+m.angularCosine*dc,
            linearVelocity:velocity,angularRate:m.frequency*(m.angularSine*cosine-m.angularCosine*sine),
            linearAcceleration:acceleration,angularAcceleration:-m.frequency*m.frequency*(m.angularSine*sine+m.angularCosine*cosine))
    }
    private static func piecewise(_ m:PiecewisePrescribedMotion,time:Double) throws(PrescribedMotionError) -> PrescribedMotionJet {
        var low=0,high=m.segments.count
        while low < high { let middle=low+(high-low)/2;if m.segments[middle].startTime <= time { low=middle+1 } else { high=middle } }
        let segment=m.segments[max(0,low-1)]
        if time == segment.startTime { return segment.start }
        if time == segment.endTime { return segment.end }
        let h=segment.endTime-segment.startTime,s=(time-segment.startTime)/h,a=segment.start,b=segment.end
        let x=try PrescribedQuintic.value(a.displacement.x,b.displacement.x,a.linearVelocity.x,b.linearVelocity.x,a.linearAcceleration.x,b.linearAcceleration.x,duration:h,fraction:s)
        let y=try PrescribedQuintic.value(a.displacement.y,b.displacement.y,a.linearVelocity.y,b.linearVelocity.y,a.linearAcceleration.y,b.linearAcceleration.y,duration:h,fraction:s)
        let z=try PrescribedQuintic.value(a.displacement.z,b.displacement.z,a.linearVelocity.z,b.linearVelocity.z,a.linearAcceleration.z,b.linearAcceleration.z,duration:h,fraction:s)
        let angle=try PrescribedQuintic.value(a.angle,b.angle,a.angularRate,b.angularRate,a.angularAcceleration,b.angularAcceleration,duration:h,fraction:s)
        let p:Vector3,v:Vector3,acceleration:Vector3
        do throws(CoreError) { p=try Vector3(x.0,y.0,z.0);v=try Vector3(x.1,y.1,z.1);acceleration=try Vector3(x.2,y.2,z.2) }
        catch { throw .mathematical(error) }
        return try PrescribedMotionJet(displacement:p,angle:angle.0,linearVelocity:v,angularRate:angle.1,linearAcceleration:acceleration,angularAcceleration:angle.2)
    }
}

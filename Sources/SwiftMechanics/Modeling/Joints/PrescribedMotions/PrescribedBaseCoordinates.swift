/// One coordinate algorithm serves both original quadratic and additive trajectory sources.
internal enum PrescribedBaseCoordinates {
    @inline(never)
    static func make(layout:BaseLayout,metadata:String,frame:EntityID,worldFrame:EntityID,time:Double,
                     planarAngle:Double?,motion:FrameMotion) throws(PrescribedMotionError) -> PrescribedBaseMotionSample {
        let q:[Double],v:[Double],a:[Double],rate:[Double]
        switch layout {
        case .fixed: throw .unsupportedChart
        case .planarFloating:
            guard let angle=planarAngle,angle.isFinite else { throw .staleSource }
            let pose:PlanarPose
            do throws(ModelError) { pose=try PlanarPose(x:motion.pose.translation.x,y:motion.pose.translation.y,angle:angle) }
            catch { throw .invalidInput }
            let encoded:BaseCoordinates
            do { encoded=try layout.encode(.planar(pose:pose,worldVelocityX:motion.velocity.linear.x,
                worldVelocityY:motion.velocity.linear.y,angularVelocityZ:motion.velocity.angular.z)) }
            catch { throw .invalidInput }
            q=encoded.q;v=encoded.v;a=[motion.acceleration.linear.x,motion.acceleration.linear.y,motion.acceleration.angular.z];rate=v
        case .spatialFloating:
            let angular:Vector3,alpha:Vector3,quaternionRate:QuaternionRate
            do throws(CoreError) {
                let inverse=motion.pose.rotation.conjugated()
                angular=try inverse.rotating(motion.velocity.angular)
                alpha=try inverse.rotating(motion.acceleration.angular)
                quaternionRate=try motion.pose.rotation.bodyRate(for:angular)
            } catch { throw .mathematical(error) }
            let encoded:BaseCoordinates
            do { encoded=try layout.encode(.spatial(pose:motion.pose,worldLinearVelocity:motion.velocity.linear,bodyAngularVelocity:angular)) }
            catch { throw .invalidInput }
            q=encoded.q;v=encoded.v
            a=[motion.acceleration.linear.x,motion.acceleration.linear.y,motion.acceleration.linear.z,alpha.x,alpha.y,alpha.z]
            rate=[motion.velocity.linear.x,motion.velocity.linear.y,motion.velocity.linear.z,quaternionRate.w,quaternionRate.x,quaternionRate.y,quaternionRate.z]
        }
        return PrescribedBaseMotionSample(metadata:metadata,layout:layout,frame:frame,worldFrame:worldFrame,time:time,
            q:q,v:v,a:a,coordinateRate:rate,motion:motion)
    }
}

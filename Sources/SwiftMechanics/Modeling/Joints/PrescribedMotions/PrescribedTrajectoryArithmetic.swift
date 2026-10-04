internal enum PrescribedTrajectoryArithmetic {
    static func identity(_ frame:EntityID,parent:EntityID,pose:RigidTransform,axis:Vector3,maximumBytes:Int) throws(PrescribedMotionError) {
        guard maximumBytes > 0,frame.key.utf8.count <= maximumBytes,parent.key.utf8.count <= maximumBytes else { throw .capacityExceeded }
        guard frame.kind == .frame,parent.kind == .frame,frame != parent else { throw .invalidFrame }
        let squaredNorm:Double
        do throws(CoreError) {
            _=try UnitQuaternion(unitW:pose.rotation.w,x:pose.rotation.x,y:pose.rotation.y,z:pose.rotation.z)
            squaredNorm=try axis.dot(axis)
        } catch { throw .mathematical(error) }
        guard abs(squaredNorm-1) <= 16*Double.ulpOfOne else { throw .invalidAxis }
    }
    static func finite(_ value:Double) throws(PrescribedMotionError) -> Double {
        guard value.isFinite else { throw .invalidInput };return value
    }
    static func sum(_ a:Int,_ b:Int) throws(PrescribedMotionError) -> Int {
        do throws(NumericalError) { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) }
    }
    static func product(_ a:Int,_ b:Int) throws(PrescribedMotionError) -> Int {
        do throws(NumericalError) { return try NumericalWork.product(a,b) } catch { throw .numerical(error) }
    }
    static func reserve(count:Int,scalars:Int,operations:Int,work:inout NumericalWork) throws(PrescribedMotionError) {
        try PrescribedBaseMotionArithmetic.reserve(try product(count,scalars),operations:try product(count,operations),work:&work)
    }
    static func continuity(_ a:PrescribedMotionJet,_ b:PrescribedMotionJet,time:Double) throws(PrescribedMotionError) {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Non-C2 motion requires actual discontinuity events and physical reconciliation. This constructor path refuses it; sampling success cannot qualify SPEC KI-006 events.
        guard a.displacement == b.displacement,a.angle == b.angle else { throw .unsupportedDiscontinuity(time:time,derivative:.position) }
        guard a.linearVelocity == b.linearVelocity,a.angularRate == b.angularRate else { throw .unsupportedDiscontinuity(time:time,derivative:.velocity) }
        guard a.linearAcceleration == b.linearAcceleration,a.angularAcceleration == b.angularAcceleration else { throw .unsupportedDiscontinuity(time:time,derivative:.acceleration) }
    }
    static func validatePolynomial(_ segment:PrescribedMotionSegment) throws(PrescribedMotionError) {
        let a=segment.start,b=segment.end,h=segment.endTime-segment.startTime
        _=try PrescribedQuintic.value(a.displacement.x,b.displacement.x,a.linearVelocity.x,b.linearVelocity.x,a.linearAcceleration.x,b.linearAcceleration.x,duration:h,fraction:0)
        _=try PrescribedQuintic.value(a.displacement.y,b.displacement.y,a.linearVelocity.y,b.linearVelocity.y,a.linearAcceleration.y,b.linearAcceleration.y,duration:h,fraction:0)
        _=try PrescribedQuintic.value(a.displacement.z,b.displacement.z,a.linearVelocity.z,b.linearVelocity.z,a.linearAcceleration.z,b.linearAcceleration.z,duration:h,fraction:0)
        _=try PrescribedQuintic.value(a.angle,b.angle,a.angularRate,b.angularRate,a.angularAcceleration,b.angularAcceleration,duration:h,fraction:0)
    }
}

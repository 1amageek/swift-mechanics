internal enum PrescribedBaseSampleComparison {
    static func matches(_ supplied:PrescribedBaseMotionSample,_ original:PrescribedBaseMotionSample) -> Bool {
        supplied.metadata == original.metadata && supplied.layout == original.layout && supplied.frame == original.frame &&
        supplied.worldFrame == original.worldFrame && supplied.time.bitPattern == original.time.bitPattern &&
        numbers(supplied.q,original.q) && numbers(supplied.v,original.v) && numbers(supplied.a,original.a) &&
        numbers(supplied.coordinateRate,original.coordinateRate) && motion(supplied.motion,original.motion)
    }
    private static func numbers(_ a:[Double],_ b:[Double]) -> Bool {
        guard a.count == b.count else { return false };for i in b.indices { if a[i].bitPattern != b[i].bitPattern { return false } };return true
    }
    private static func vector(_ a:Vector3,_ b:Vector3) -> Bool { a.x.bitPattern == b.x.bitPattern && a.y.bitPattern == b.y.bitPattern && a.z.bitPattern == b.z.bitPattern }
    private static func motion(_ a:FrameMotion,_ b:FrameMotion) -> Bool {
        let x=a.pose.rotation,y=b.pose.rotation
        return vector(a.pose.translation,b.pose.translation) && x.w.bitPattern == y.w.bitPattern && x.x.bitPattern == y.x.bitPattern &&
            x.y.bitPattern == y.y.bitPattern && x.z.bitPattern == y.z.bitPattern && vector(a.velocity.angular,b.velocity.angular) &&
            vector(a.velocity.linear,b.velocity.linear) && vector(a.acceleration.angular,b.acceleration.angular) && vector(a.acceleration.linear,b.acceleration.linear)
    }
}

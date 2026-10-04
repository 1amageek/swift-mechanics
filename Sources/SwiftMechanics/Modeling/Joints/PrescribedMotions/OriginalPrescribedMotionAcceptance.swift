/// Original immutable coefficients, not opaque diagnostics, establish imposed-motion authority.
public enum OriginalPrescribedMotionAcceptance {
    public static func validated(_ supplied:PrescribedMotionSample,program:PrescribedMotionProgram,time:Double,
                                 policy:PrescribedMotionPolicy,work:inout NumericalWork) throws(PrescribedMotionError) -> PrescribedMotionSample {
        guard supplied.anchors.count <= policy.maximumSamples,supplied.metadata.utf8.count <= policy.maximumMetadataBytes else { throw .capacityExceeded }
        for sample in supplied.anchors { guard sample.frame.key.utf8.count <= policy.maximumIdentifierBytes else { throw .capacityExceeded } }
        let original=try AnalyticPrescribedMotionSampler().sample(program,time:time,policy:policy,work:&work)
        do throws(NumericalError) { try work.chargeOperations(try NumericalWork.sum(program.metadata.utf8.count,try NumericalWork.product(64,original.anchors.count))) }
        catch { throw .numerical(error) }
        guard supplied.metadata == program.metadata,supplied.time.bitPattern == time.bitPattern,matches(supplied.anchors,original.anchors) else { throw .staleSource }
        return original
    }
    internal static func matches(_ supplied:[PrescribedAnchorState],_ original:[PrescribedAnchorState]) -> Bool {
        guard supplied.count == original.count else { return false }
        for (a,b) in zip(supplied,original) {
            guard a.frame == b.frame,a.time.bitPattern == b.time.bitPattern else { return false }
            func vector(_ x:Vector3,_ y:Vector3) -> Bool {
                x.x.bitPattern == y.x.bitPattern && x.y.bitPattern == y.y.bitPattern && x.z.bitPattern == y.z.bitPattern
            }
            let x=a.motion,y=b.motion,r=x.pose.rotation,t=y.pose.rotation
            guard vector(x.pose.translation,y.pose.translation),r.w.bitPattern == t.w.bitPattern,r.x.bitPattern == t.x.bitPattern,
                  r.y.bitPattern == t.y.bitPattern,r.z.bitPattern == t.z.bitPattern,
                  vector(x.velocity.angular,y.velocity.angular),vector(x.velocity.linear,y.velocity.linear),
                  vector(x.acceleration.angular,y.acceleration.angular),vector(x.acceleration.linear,y.acceleration.linear) else { return false }
        }
        return true
    }
}

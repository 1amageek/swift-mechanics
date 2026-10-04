/// Callers bound physical scalar counts and anchor metadata before exact saved-prefix comparison.
internal enum RuntimePhysicalIdentity {
    static func equal(_ left:KinematicState,_ right:KinematicState) -> Bool {
        guard left.revision == right.revision,left.time.bitPattern == right.time.bitPattern,
              left.q.elementsEqual(right.q,by: { $0.bitPattern == $1.bitPattern }),
              left.v.elementsEqual(right.v,by: { $0.bitPattern == $1.bitPattern }),
              left.acceleration.elementsEqual(right.acceleration,by: { $0.bitPattern == $1.bitPattern }),
              left.prescribedAnchors.count == right.prescribedAnchors.count else { return false }
        for (a,b) in zip(left.prescribedAnchors,right.prescribedAnchors) {
            let x=a.motion.pose.rotation,y=b.motion.pose.rotation
            guard a.frame == b.frame,a.time.bitPattern == b.time.bitPattern,
                  x.w.bitPattern == y.w.bitPattern,x.x.bitPattern == y.x.bitPattern,
                  x.y.bitPattern == y.y.bitPattern,x.z.bitPattern == y.z.bitPattern,
                  vector(a.motion.pose.translation,b.motion.pose.translation),
                  vector(a.motion.velocity.angular,b.motion.velocity.angular),vector(a.motion.velocity.linear,b.motion.velocity.linear),
                  vector(a.motion.acceleration.angular,b.motion.acceleration.angular),vector(a.motion.acceleration.linear,b.motion.acceleration.linear) else { return false }
        }
        return true
    }
    private static func vector(_ a:Vector3,_ b:Vector3) -> Bool {
        a.x.bitPattern == b.x.bitPattern && a.y.bitPattern == b.y.bitPattern && a.z.bitPattern == b.z.bitPattern
    }
}

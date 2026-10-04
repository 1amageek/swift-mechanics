internal final class ToothPairKinematics: Sendable {
    let first: BodyKinematics
    let second: BodyKinematics
    let poseA: RigidTransform
    let witness: CollisionWitness
    private init(first: BodyKinematics, second: BodyKinematics, poseA: RigidTransform, witness: CollisionWitness) {
        self.first=first; self.second=second; self.poseA=poseA; self.witness=witness
    }
    @inline(never)
    static func evaluate(shared: ToothContactPhysics, pair: ToothContactPair, snapshot: KinematicSnapshot,
                         policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> ToothPairKinematics {
        let model=shared.model, a=model.teeth[pair.firstProxy], b=model.teeth[pair.secondProxy]
        let first: BodyKinematics, second: BodyKinematics
        do { first=try snapshot.body(a.proxy.geometry.bodyID); second=try snapshot.body(b.proxy.geometry.bodyID) } catch { throw .joint(error) }
        let poseA=try ToothArithmetic.core { () throws(CoreError) in try first.motion.pose.composed(with:a.colliderToBody) }
        let poseB=try ToothArithmetic.core { () throws(CoreError) in try second.motion.pose.composed(with:b.colliderToBody) }
        let proxyA=a.proxy.moved(to:poseA), proxyB=b.proxy.moved(to:poseB)
        let reserved=try ToothArithmetic.slots(teeth:model.teeth.count,contacts:model.contacts.count)
        let witness=try ToothArithmetic.collision(reserved:reserved,policy:policy,work:&work) { (local: inout CollisionWork) throws(CollisionError) in
            try shared.geometry.witness(first:proxyA,second:proxyB,policy:policy.collision,work:&local)
        }
        let original=try ToothArithmetic.collision(reserved:reserved,policy:policy,work:&work) { (local: inout CollisionWork) throws(CollisionError) in
            try AnalyticCollisionQueries().witness(first:proxyA,second:proxyB,policy:policy.collision,work:&local)
        }
        guard witness.pair == original.pair, witness.poseA == poseA, witness.poseB == poseB,
              witness.featureA == original.featureA, witness.featureB == original.featureB,
              witness.approximationError == original.approximationError else { throw .invalidSupplierOutput }
        guard witness.degeneracy == .regular, original.degeneracy == .regular else { throw .unsupportedDomain }
        try ToothArithmetic.vector(witness.pointA,original.pointA,policy:policy)
        try ToothArithmetic.vector(witness.pointB,original.pointB,policy:policy)
        let normalError=try ToothArithmetic.core { () throws(CoreError) in try witness.normal.subtracting(original.normal).magnitude() }
        guard normalError <= policy.collision.normalTolerance, abs(witness.separation-original.separation) <= policy.collision.lengthTolerance else { throw .invalidSupplierOutput }
        return ToothPairKinematics(first:first,second:second,poseA:poseA,witness:witness)
    }
}

internal final class ContactRangeTactileKinematics: Sendable {
    let witness:CollisionWitness
    let point:Vector3
    let basis:ContactBasis
    let relative:Vector3
    let angular:Vector3
    let input:ContactCurrentInput
    let side:TactileObservation.Side
    private init(witness:CollisionWitness,point:Vector3,basis:ContactBasis,relative:Vector3,angular:Vector3,
                 input:ContactCurrentInput,side:TactileObservation.Side) {
        self.witness=witness;self.point=point;self.basis=basis;self.relative=relative
        self.angular=angular;self.input=input;self.side=side
    }
    @inline(never)
    static func prepare(scene:ContactRangeScene,mount:ObservationMount,contact:TactileContactBinding,
                        geometry:any CollisionGeometryQuerying,policy:ContactRangeObservationPolicy,
                        collisionWork:inout CollisionWork,work:inout NumericalWork)
        throws(ContactRangeObservationError) -> ContactRangeTactileKinematics {
        guard policy.maximumTactileBindings >= 1 else { throw .capacityExceeded }
        try ContactRangeArithmetic.history(contact.accepted,policy,&work)
        try ContactRangeArithmetic.metadata([contact.firstCollider.key,contact.secondCollider.key,contact.pair.firstMaterial.id.key,contact.pair.secondMaterial.id.key],policy,&work)
        try ContactRangeArithmetic.charge(2048,&work);try ContactRangeArithmetic.storage(256,&work)
        guard let a=scene.collision.proxies.first(where:{$0.geometry.colliderID == contact.firstCollider}),
              let b=scene.collision.proxies.first(where:{$0.geometry.colliderID == contact.secondCollider}),
              a.geometry.bodyID != b.geometry.bodyID,a.filter.enabled,b.filter.enabled,!a.filter.isTrigger,!b.filter.isTrigger,
              a.filter.layerBits & b.filter.maskBits != 0,b.filter.layerBits & a.filter.maskBits != 0 else { throw .invalidInput }
        let id=contact.accepted.identity
        guard id.firstBody == ModelReference(id:a.geometry.bodyID,revision:scene.source.model.stamp.revision),
              id.secondBody == ModelReference(id:b.geometry.bodyID,revision:scene.source.model.stamp.revision),
              id.frame == ModelReference(id:scene.source.snapshot.tree.worldFrame,revision:scene.source.snapshot.tree.revision),
              id.firstGeometryRevision == a.geometry.geometryRevision,id.secondGeometryRevision == b.geometry.geometryRevision,
              id.tangentLayoutRevision == contact.tangentLayoutRevision,contact.pair == contact.accepted.pair else { throw .staleSource }
        guard contact.accepted.timeSeconds == scene.source.state.state.time else { throw .temporalMismatch }
        let side:TactileObservation.Side
        if mount.body == a.geometry.bodyID { side = .first }
        else if mount.body == b.geometry.bodyID { side = .second }
        else { throw .invalidInput }
        let supplied=try ContactRangeArithmetic.collision(&collisionWork) { (ledger:inout CollisionWork) throws(CollisionError) in
            try geometry.witness(first:a,second:b,policy:policy.query,work:&ledger)
        }
        try ContactRangeArithmetic.check(policy)
        let original=try ContactRangeArithmetic.collision(&collisionWork) { (ledger:inout CollisionWork) throws(CollisionError) in
            try AnalyticCollisionQueries().witness(first:a,second:b,policy:policy.query,work:&ledger)
        }
        try ContactRangeEvidence.witness(supplied,original,policy:policy,work:&work)
        // FIXME(INCOMPLETE_IMPLEMENTATION): A degenerate contact does not establish a material tangent chart.
        // This tactile path refuses it until the selected degeneracy has original physical-axis evidence.
        guard original.degeneracy == .regular else { throw .unsupportedChart }
        guard let first=scene.source.snapshot.bodies.first(where:{$0.body == a.geometry.bodyID}),
              let second=scene.source.snapshot.bodies.first(where:{$0.body == b.geometry.bodyID}) else { throw .staleSource }
        let point=try ContactRangeArithmetic.core { () throws(CoreError) in try original.pointA.adding(original.pointB).scaled(by:0.5) }
        let relative=try ContactRangeArithmetic.core { () throws(CoreError) in
            let ra=try point.subtracting(first.motion.pose.translation),rb=try point.subtracting(second.motion.pose.translation)
            let va=try first.motion.velocity.linear.adding(first.motion.velocity.angular.cross(ra))
            let vb=try second.motion.velocity.linear.adding(second.motion.velocity.angular.cross(rb))
            return try vb.subtracting(va)
        }
        let angular=try ContactRangeArithmetic.core { () throws(CoreError) in try second.motion.velocity.angular.subtracting(first.motion.velocity.angular) }
        let basis=try materialBasis(contact:contact,pose:a.pose,normal:original.normal,frame:id.frame,policy:policy)
        let input:ContactCurrentInput
        do throws(ContactCurrentError) { input=try ContactCurrentInput(identity:id,basis:basis,separation:original.separation,
            relativeVelocity:relative,relativeAngularVelocity:angular,timeSeconds:scene.source.state.state.time) } catch { throw .current(error) }
        return ContactRangeTactileKinematics(witness:original,point:point,basis:basis,relative:relative,angular:angular,input:input,side:side)
    }
    @inline(never)
    private static func materialBasis(contact:TactileContactBinding,pose:RigidTransform,normal:Vector3,frame:ModelReference,
                                      policy:ContactRangeObservationPolicy) throws(ContactRangeObservationError) -> ContactBasis {
        let projected=try ContactRangeArithmetic.core { () throws(CoreError) in
            let world=try pose.rotation.rotating(contact.firstMaterialTangentInCollider.normalized())
            return try world.subtracting(normal.scaled(by:normal.dot(world)))
        }
        let length=try ContactRangeArithmetic.core { () throws(CoreError) in try projected.magnitude() }
        guard length > policy.query.normalTolerance else { throw .unsupportedChart }
        let rotation=try ContactRangeArithmetic.core { () throws(CoreError) in
            let e1=try projected.normalized(),e2=try normal.cross(e1)
            return try UnitQuaternion(matrix:Matrix3(e1.x,e2.x,normal.x,e1.y,e2.y,normal.y,e1.z,e2.z,normal.z),
                tolerance:NumericalTolerance(absolute:policy.query.normalTolerance,relative:0))
        }
        do throws(ContactLawError) { return try ContactBasis(frame:frame,contactToQuery:rotation) } catch { throw .current(.law(error)) }
    }
}

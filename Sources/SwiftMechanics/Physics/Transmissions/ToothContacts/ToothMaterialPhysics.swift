internal final class ToothMaterialPhysics: Sendable {
    let shared: ToothContactPhysics
    let current: any ContactCurrentEvaluating
    init(shared: ToothContactPhysics, current: any ContactCurrentEvaluating) { self.shared=shared; self.current=current }
    @inline(never)
    func evaluate(state: KinematicState, histories: [ContactHistory], start: Double, step: Double?,
                  policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> ToothMaterialSample {
        let model=shared.model
        guard histories.count == model.contacts.count else { throw .staleSource }
        let reserved=try ToothArithmetic.slots(teeth:model.teeth.count,contacts:model.contacts.count)
        try ToothArithmetic.check(policy); try work.charge(ToothArithmetic.product(1024,model.contacts.count),storage:reserved)
        let snapshot=try ToothArithmetic.snapshot(model,state:state,policy:policy,work:&work)
        guard snapshot.coordinateRate == state.v else { throw .unsupportedDomain }
        var observations:[MaterialToothContactSample]=[], next:[ContactHistory]=[], loads:[BodyWrenchContribution]=[]
        observations.reserveCapacity(model.contacts.count); next.reserveCapacity(model.contacts.count)
        loads.reserveCapacity(try ToothArithmetic.product(2,model.contacts.count))
        var normal=0.0, tangent=0.0, cohesion=0.0, dn=0.0, dr=0.0, dt=0.0, power=0.0
        for i in model.contacts.indices {
            let sample=try sample(index:i,snapshot:snapshot,history:histories[i],start:start,step:step,policy:policy,work:&work)
            observations.append(sample); next.append(sample.evidence.history)
            normal=try ToothArithmetic.value(normal+sample.normalStoredEnergy)
            tangent=try ToothArithmetic.value(tangent+sample.tangentialStoredEnergy)
            cohesion=try ToothArithmetic.value(cohesion+sample.cohesivePotentialEnergy)
            dn=try ToothArithmetic.value(dn+sample.normalDissipationPower); dr=try ToothArithmetic.value(dr+sample.resistanceDissipationPower)
            dt=try ToothArithmetic.value(dt+sample.tangentialDissipationEnergy); power=try ToothArithmetic.value(power+sample.relativeMechanicalPower)
            let pair=model.contacts[i]
            let forceA=try ToothArithmetic.core { () throws(CoreError) in try sample.forceOnB.scaled(by:-1) }
            let coupleA=try ToothArithmetic.core { () throws(CoreError) in try sample.coupleOnB.scaled(by:-1) }
            do {
                loads.append(try BodyWrenchContribution(body:model.teeth[pair.firstProxy].proxy.geometry.bodyID,frame:model.tree.worldFrame,
                    referencePoint:sample.applicationPoint,wrench:SpatialWrench(torque:coupleA,force:forceA),channel:.contact,
                    potentialEnergy:sample.normalStoredEnergy+sample.tangentialStoredEnergy+sample.cohesivePotentialEnergy,
                    dissipatedPower:sample.normalDissipationPower+sample.resistanceDissipationPower))
                loads.append(try BodyWrenchContribution(body:model.teeth[pair.secondProxy].proxy.geometry.bodyID,frame:model.tree.worldFrame,
                    referencePoint:sample.applicationPoint,wrench:SpatialWrench(torque:sample.coupleOnB,force:sample.forceOnB),channel:.contact,
                    potentialEnergy:0,dissipatedPower:0))
            } catch { throw .dynamics(error) }
        }
        let rigid=try shared.rigid.evaluate(snapshot:snapshot,loads:loads,stored:ToothArithmetic.value(normal+tangent+cohesion),
            loss:ToothArithmetic.value(dn+dr),contactPower:power,reserved:reserved,policy:policy,work:&work)
        return ToothMaterialSample(rigid:rigid,observations:observations,histories:next,normal:normal,tangent:tangent,cohesion:cohesion,
            normalPower:dn,resistancePower:dr,tangentLoss:dt)
    }
    @inline(never)
    private func sample(index: Int, snapshot: KinematicSnapshot, history: ContactHistory, start: Double, step: Double?,
                        policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> MaterialToothContactSample {
        let model=shared.model, pair=model.contacts[index]
        guard history.identity == (try shared.identity(pair)), history.pair == pair.law, history.timeSeconds == start else { throw .staleSource }
        let k=try ToothPairKinematics.evaluate(shared:shared,pair:pair,snapshot:snapshot,policy:policy,work:&work)
        try work.charge(1024)
        let point=try ToothArithmetic.core { () throws(CoreError) in try k.witness.pointA.adding(k.witness.pointB).scaled(by:0.5) }
        let ra=try ToothArithmetic.core { () throws(CoreError) in try point.subtracting(k.first.motion.pose.translation) }
        let rb=try ToothArithmetic.core { () throws(CoreError) in try point.subtracting(k.second.motion.pose.translation) }
        let va=try ToothArithmetic.core { () throws(CoreError) in try k.first.motion.velocity.linear.adding(k.first.motion.velocity.angular.cross(ra)) }
        let vb=try ToothArithmetic.core { () throws(CoreError) in try k.second.motion.velocity.linear.adding(k.second.motion.velocity.angular.cross(rb)) }
        let relative=try ToothArithmetic.core { () throws(CoreError) in try vb.subtracting(va) }
        let angular=try ToothArithmetic.core { () throws(CoreError) in try k.second.motion.velocity.angular.subtracting(k.first.motion.velocity.angular) }
        let basis=try basis(pair:pair,kinematics:k,frame:history.identity.frame,policy:policy)
        let reserved=try ToothArithmetic.slots(teeth:model.teeth.count,contacts:model.contacts.count)
        let evidence: MaterialToothContactEvidence, endpoint: ContactHistory
        var tangentLoss=0.0
        if let step {
            let input: ContactInput
            do { input=try ContactInput(identity:history.identity,basis:basis,separation:k.witness.separation,relativeVelocity:relative,
                relativeAngularVelocity:angular,startTimeSeconds:start,timeStepSeconds:step) } catch { throw .contact(error) }
            let supplied=try ToothArithmetic.contact(reserved:reserved,policy:policy,work:&work) { (local: inout ContactWork) throws(ContactLawError) in
                try self.shared.laws.evaluate(input:input,pair:pair.law,accepted:history,policy:policy.contact,work:&local)
            }
            let original=try ToothArithmetic.contact(reserved:reserved,policy:policy,work:&work) { (local: inout ContactWork) throws(ContactLawError) in
                try CompliantContactEvaluator().evaluate(input:input,pair:pair.law,accepted:history,policy:policy.contact,work:&local)
            }
            try ToothMaterialAcceptance.trial(supplied,original,work:&work)
            endpoint=supplied.trialHistory; evidence = .trial(supplied); tangentLoss=supplied.tangentialDissipationEnergy
        } else { endpoint=history; evidence = .current(try currentResponse(pair:pair,history:history,basis:basis,witness:k.witness,
            relative:relative,angular:angular,time:snapshot.time,reserved:reserved,policy:policy,work:&work)) }
        let response: ContactCurrentResponse
        switch evidence {
        case .current(let value): response=value
        case .trial(let value):
            response=try currentResponse(pair:pair,history:endpoint,basis:basis,witness:k.witness,relative:relative,angular:angular,
                time:snapshot.time,reserved:reserved,policy:policy,work:&work)
            try ToothMaterialAcceptance.endpoint(value,response,work:&work)
        }
        let forceA=try ToothArithmetic.core { () throws(CoreError) in try response.forceOnB.scaled(by:-1) }
        let ta=try ToothArithmetic.core { () throws(CoreError) in try ra.cross(forceA).subtracting(response.coupleOnB) }
        let tb=try ToothArithmetic.core { () throws(CoreError) in try rb.cross(response.forceOnB).adding(response.coupleOnB) }
        let vn=try ToothArithmetic.core { () throws(CoreError) in try k.witness.normal.dot(relative) }
        let slip=try ToothArithmetic.core { () throws(CoreError) in try relative.subtracting(k.witness.normal.scaled(by:vn)) }
        return MaterialToothContactSample(pair:pair,witness:k.witness,applicationPoint:point,basis:basis,relative:relative,angular:angular,
            slip:slip,evidence:evidence,current:response,tangentLoss:tangentLoss,firstTorque:ta,secondTorque:tb)
    }
    @inline(never)
    private func currentResponse(pair: ToothContactPair, history: ContactHistory, basis: ContactBasis, witness: CollisionWitness,
                                 relative: Vector3, angular: Vector3, time: Double, reserved: Int, policy: ToothContactPolicy,
                                 work: inout ToothContactWork) throws(ToothContactError) -> ContactCurrentResponse {
        let input: ContactCurrentInput
        do { input=try ContactCurrentInput(identity:history.identity,basis:basis,separation:witness.separation,
            relativeVelocity:relative,relativeAngularVelocity:angular,timeSeconds:time) } catch { throw .current(error) }
        let supplied=try ToothArithmetic.current(reserved:reserved,policy:policy,work:&work) { (local: inout ContactWork) throws(ContactCurrentError) in
            try self.current.sample(input:input,pair:pair.law,accepted:history,policy:policy.contact,work:&local)
        }
        let original=try ToothArithmetic.current(reserved:reserved,policy:policy,work:&work) { (local: inout ContactWork) throws(ContactCurrentError) in
            try CompliantContactCurrentEvaluator().sample(input:input,pair:pair.law,accepted:history,policy:policy.contact,work:&local)
        }
        try ToothMaterialAcceptance.current(supplied,original,work:&work)
        return supplied
    }
    private func basis(pair: ToothContactPair, kinematics k: ToothPairKinematics, frame: ModelReference,
                       policy: ToothContactPolicy) throws(ToothContactError) -> ContactBasis {
        let rotation: UnitQuaternion
        if let material=pair.firstMaterialTangent {
            let n=k.witness.normal
            let projected=try ToothArithmetic.core { () throws(CoreError) in
                let world=try k.poseA.rotation.rotating(material.directionInCollider)
                return try world.subtracting(n.scaled(by:n.dot(world)))
            }
            guard try ToothArithmetic.core({ () throws(CoreError) in try projected.magnitude() }) > policy.collision.normalTolerance else {
                throw .materialChartSingularity
            }
            rotation=try ToothArithmetic.core { () throws(CoreError) in
                let e1=try projected.normalized(), e2=try n.cross(e1)
                let matrix=try Matrix3(e1.x,e2.x,n.x,e1.y,e2.y,n.y,e1.z,e2.z,n.z)
                return try UnitQuaternion(matrix:matrix,tolerance:NumericalTolerance(absolute:policy.collision.normalTolerance,relative:0))
            }
        } else {
            rotation=try ToothArithmetic.core { () throws(CoreError) in
                if k.witness.normal.z == -1, k.witness.normal.x == 0, k.witness.normal.y == 0 { return try UnitQuaternion(axis:.unitX,angle:.pi) }
                return try UnitQuaternion(w:1+k.witness.normal.z,x:-k.witness.normal.y,y:k.witness.normal.x,z:0)
            }
        }
        do { return try ContactBasis(frame:frame,contactToQuery:rotation) } catch { throw .contact(error) }
    }
}

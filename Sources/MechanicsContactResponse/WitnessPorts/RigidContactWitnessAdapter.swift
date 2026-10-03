import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints
import MechanicsDynamics
import MechanicsCollision
import MechanicsContactLaws
public struct RigidContactWitnessAdapter: ContactWitnessAdapting {
    public init() {}
    public func prepare(_ binding: WitnessContact, input: ContactResponseInput, policy: ContactResponsePolicy, work: inout NumericalWork) throws(ContactResponseError) -> PreparedContact {
        try ResponseArithmetic.check(policy)
        let snapshot=input.system.input.snapshot, n=input.system.velocityCount, witness=binding.witness
        guard input.contacts.count <= policy.maximumContacts, input.collision.proxies.count <= policy.maximumColliders,
              snapshot.bodies.count <= policy.maximumBodies, n <= policy.maximumVelocities else { throw .capacityExceeded }
        guard input.expectedCollisionRevision == input.collision.revision else { throw .staleCollision }
        guard input.expectedModelRevision == snapshot.tree.revision else { throw .staleModel }
        guard binding.firstProxyIndex >= 0, binding.secondProxyIndex >= 0, binding.firstProxyIndex < input.collision.proxies.count,
              binding.secondProxyIndex < input.collision.proxies.count, binding.firstProxyIndex != binding.secondProxyIndex else { throw .invalidInput }
        let a=input.collision.proxies[binding.firstProxyIndex], b=input.collision.proxies[binding.secondProxyIndex]
        guard try ResponseArithmetic.geometry(witness.pair.first,a.geometry,policy:policy,work:&work),
              try ResponseArithmetic.geometry(witness.pair.second,b.geometry,policy:policy,work:&work) else { throw .staleCollision }
        try ResponseArithmetic.charge(2,&work)
        guard a.filter.enabled, b.filter.enabled, !a.filter.isTrigger, !b.filter.isTrigger,
              a.filter.layerBits & b.filter.maskBits != 0, b.filter.layerBits & a.filter.maskBits != 0 else { throw .ineligiblePair }
        let identity=binding.accepted.identity
        // FIXME(INCOMPLETE_IMPLEMENTATION): Material-site nodal contact is not implemented by this rigid mass adapter. This public preparation path rejects it until actual nodal geometry, mass and power evidence exists; rigid columns must not imply deforming response success.
        guard identity.firstMaterialSite == nil, identity.secondMaterialSite == nil else { throw .unsupportedRepresentation }
        try ResponseArithmetic.key(identity.key,policy:policy,work:&work)
        guard try ResponseArithmetic.id(identity.firstBody.id,a.geometry.bodyID,policy:policy,work:&work),
              try ResponseArithmetic.id(identity.secondBody.id,b.geometry.bodyID,policy:policy,work:&work),
              identity.firstBody.revision == snapshot.tree.revision, identity.secondBody.revision == snapshot.tree.revision else { throw .staleModel }
        guard try ResponseArithmetic.id(identity.frame.id,snapshot.tree.worldFrame,policy:policy,work:&work),
              try ResponseArithmetic.id(identity.frame.id,a.geometry.frameID,policy:policy,work:&work),
              try ResponseArithmetic.id(identity.frame.id,b.geometry.frameID,policy:policy,work:&work),
              try ResponseArithmetic.id(binding.basis.frame.id,identity.frame.id,policy:policy,work:&work),
              identity.frame.revision == a.geometry.frameRevision, identity.frame.revision == b.geometry.frameRevision,
              binding.basis.frame.revision == identity.frame.revision, identity.frame.revision == snapshot.tree.revision else { throw .frameMismatch }
        guard identity.firstGeometryRevision == a.geometry.geometryRevision, identity.secondGeometryRevision == b.geometry.geometryRevision,
              binding.accepted.timeSeconds == snapshot.time, identity.tangentLayoutRevision == binding.tangentLayoutRevision else { throw .staleHistory }
        guard witness.degeneracy == .regular, witness.approximationError == 0, a.geometry.resolution == .analytic, b.geometry.resolution == .analytic else { throw .invalidWitness }
        let balance=try ResponseArithmetic.norm(ResponseArithmetic.sub(ResponseArithmetic.sub(witness.pointB,witness.pointA,&work),ResponseArithmetic.scale(witness.normal,witness.separation,&work),&work),&work)
        let normalError=abs(try ResponseArithmetic.norm(witness.normal,&work)-1)
        let basisError=try ResponseArithmetic.norm(ResponseArithmetic.sub(binding.basis.normal,witness.normal,&work),&work)
        guard balance <= policy.lengthTolerance, normalError <= policy.normalTolerance, basisError <= policy.normalTolerance else { throw .invalidWitness }
        guard try ResponseArithmetic.samePose(witness.poseA,a.pose,policy:policy,work:&work),
              try ResponseArithmetic.samePose(witness.poseB,b.pose,policy:policy,work:&work) else { throw .stalePose }
        let first=try body(a.geometry.bodyID,input:input,policy:policy,work:&work), second=try body(b.geometry.bodyID,input:input,policy:policy,work:&work)
        guard try ResponseArithmetic.placement(first.motion.pose,binding.firstColliderToBody,proxy:a.pose,policy:policy,work:&work),
              try ResponseArithmetic.placement(second.motion.pose,binding.secondColliderToBody,proxy:b.pose,policy:policy,work:&work) else { throw .stalePose }
        try ResponseArithmetic.key(binding.pair.firstMaterial.id.key,policy:policy,work:&work)
        try ResponseArithmetic.key(binding.pair.secondMaterial.id.key,policy:policy,work:&work)
        try ResponseArithmetic.key(binding.accepted.pair.firstMaterial.id.key,policy:policy,work:&work)
        try ResponseArithmetic.key(binding.accepted.pair.secondMaterial.id.key,policy:policy,work:&work)
        try ResponseArithmetic.charge(64,&work)
        guard binding.pair == binding.accepted.pair else { throw .staleHistory }
        let stiffness: Double
        // FIXME(INCOMPLETE_IMPLEMENTATION): Coupled friction, damped/nonlinear normal, cohesive and impact selections are not implemented. This actual response path rejects them until original model-specific coupled equations and independent evidence exist; no selected law may be silently replaced.
        guard case .linear(let k,let damping,_,_)=binding.pair.parameters.normal, damping == 0,
              binding.pair.parameters.friction == .none, binding.pair.parameters.cohesion == .none,
              binding.pair.parameters.resistance.rollingCoefficient == 0, binding.pair.parameters.resistance.spinningCoefficient == 0,
              binding.pair.lossPolicy == .compliantDampingOnly else { throw .unsupportedLaw }
        stiffness=k
        try ResponseArithmetic.storage(n,&work)
        let ra=try ResponseArithmetic.sub(witness.pointA,first.motion.pose.translation,&work), rb=try ResponseArithmetic.sub(witness.pointB,second.motion.pose.translation,&work)
        let driftA=try point(first.prescribedDriftVelocity,offset:ra,work:&work), driftB=try point(second.prescribedDriftVelocity,offset:rb,work:&work)
        let drift=try ResponseArithmetic.sub(driftB,driftA,&work), normalDrift=try ResponseArithmetic.dot(witness.normal,drift,&work)
        let columnsA: ArraySlice<SpatialMotion>, columnsB: ArraySlice<SpatialMotion>
        do { columnsA=try snapshot.geometricColumns(body:first.body); columnsB=try snapshot.geometricColumns(body:second.body) } catch { throw .joints(error) }
        var row=[Double](repeating:0,count:n)
        for i in 0..<n {
            try ResponseArithmetic.check(policy)
            let ja=try point(columnsA[columnsA.startIndex+i],offset:ra,work:&work), jb=try point(columnsB[columnsB.startIndex+i],offset:rb,work:&work)
            row[i]=try ResponseArithmetic.dot(witness.normal,ResponseArithmetic.sub(jb,ja,&work),&work)
        }
        return PreparedContact(binding:binding,firstBody:first,secondBody:second,firstOffset:ra,secondOffset:rb,normalRow:row,normalDrift:normalDrift,relativeDrift:drift,stiffness:stiffness)
    }
    private func body(_ id: EntityID,input: ContactResponseInput,policy: ContactResponsePolicy,work: inout NumericalWork) throws(ContactResponseError) -> BodyKinematics {
        for body in input.system.input.snapshot.bodies { if try ResponseArithmetic.id(id,body.body,policy:policy,work:&work) { return body } }
        throw .staleModel
    }
    private func point(_ motion: SpatialMotion,offset: Vector3,work: inout NumericalWork) throws(ContactResponseError) -> Vector3 {
        try ResponseArithmetic.add(motion.linear,ResponseArithmetic.cross(motion.angular,offset,&work),&work)
    }
}

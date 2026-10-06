public struct PrismaticControlPlant: Sendable {
    public let model:CompiledMechanicalModel
    public let port:ScalarControlPort
    public let disturbanceNewtons:Double
    internal let inertias:[RigidBodyInertia]
    internal let movingMass:Double
    public init(model:CompiledMechanicalModel,port:ScalarControlPort,disturbanceNewtons:Double,policy:ControlPolicy,work:inout NumericalWork) throws(ControlFailure) {
        try ControlArithmetic.check(policy)
        guard model.tree.bodies.count == 2,model.descriptor.bodies.count == 2,model.tree.joints.count == 1,model.descriptor.joints.count == 1,
              model.tree.layout.positionCount == 1,model.tree.layout.velocityCount == 1,model.tree.rootBase == .fixed,
              model.descriptor.rootAuthority == .fixed,disturbanceNewtons.isFinite else { throw ControlFailure(.unsupportedDomain,phase:"plant") }
        for body in model.tree.bodies { try ControlArithmetic.metadata(body.id.key,policy:policy,work:&work);try ControlArithmetic.metadata(body.frame.key,policy:policy,work:&work) }
        for text in [model.stamp.identity,model.descriptor.worldFrame.key,model.tree.joints[0].id.key,model.tree.joints[0].parentBody.key,
                     model.tree.joints[0].childBody.key,model.tree.joints[0].parentAnchor.frame.key,model.tree.joints[0].childAnchor.frame.key] {
            try ControlArithmetic.metadata(text,policy:policy,work:&work)
        }
        var actuation=ActuationWork(budget:policy.actuation)
        do { try port.binding.validate(model:model,work:&actuation) } catch { throw ControlFailure(.actuation(error),phase:"plant") }
        try ControlArithmetic.charge(64,work:&work,policy:policy)
        let joint=model.descriptor.joints[0]
        guard joint.authority == .dynamicState,joint.record.manifold.kind == .prismatic,joint.record.id == port.binding.joint,
              joint.record.parentAnchor.frame == port.parentAnchorFrame else { throw ControlFailure(.incompatiblePort,phase:"plant") }
        // FIXME(INCOMPLETE_IMPLEMENTATION): General articulated, prescribed-anchor and constrained plants reach construction here.
        // Their complete force/time evolution and controller-state association require independent proofs before admission.
        for anchor in [joint.record.parentAnchor,joint.record.childAnchor] {
            guard case .fixed=anchor.placement else { throw ControlFailure(.unsupportedDomain,phase:"plant") }
        }
        do { try work.requireStorage(128) } catch { throw ControlFailure(.numerical(error),phase:"plant") }
        var values:[RigidBodyInertia]=[];values.reserveCapacity(2)
        var mass:Double?
        for body in model.tree.bodies {
            guard let record=model.descriptor.bodies.first(where:{$0.id == body.id}),case .spatial(let spatial)=record else { throw ControlFailure(.unsupportedDomain,phase:"plant") }
            guard let representation=spatial.inertia else { throw ControlFailure(.unsupportedDomain,phase:"plant-inertia") }
            let properties=representation.properties
            do { values.append(try RigidBodyInertia(body:body.id,frame:body.frame,properties:properties)) } catch { throw ControlFailure(.dynamics(error),phase:"plant") }
            if body.id == joint.record.childBody { guard spatial.mode == .dynamic,properties.mass > 0 else { throw ControlFailure(.unsupportedDomain,phase:"plant") };mass=properties.mass }
            else { guard spatial.mode == .static else { throw ControlFailure(.unsupportedDomain,phase:"plant") } }
        }
        guard let mass else { throw ControlFailure(.invalidInput,phase:"plant") }
        self.model=model;self.port=port;self.disturbanceNewtons=disturbanceNewtons;inertias=values;movingMass=mass
    }
}

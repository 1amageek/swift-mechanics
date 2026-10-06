
public struct ReferenceWrenchObserver: WrenchObserving {
    private let kinematics:any KinematicObserving
    public init(kinematics:any KinematicObserving = ReferenceKinematicObserver()) { self.kinematics=kinematics }
    @inline(never)
    public func physical(source:ObservationSource,mount:ObservationMount,input:IdentifiedPhysicalWrench,options:WrenchObservationOptions,
                         gravity:ObservationGravity? = nil,policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> PhysicalWrenchObservation {
        try ObservationArithmetic.admit(source,policy:policy,work:&work)
        try ObservationArithmetic.metadata([input.path.key,input.body.key,input.model.identity,input.frame.key],policy:policy,work:&work)
        guard input.model == source.model.stamp,input.timeSeconds == source.state.state.time,input.body == mount.body else { throw .staleSource }
        let mounted=try ObservationArithmetic.mounted(kinematics,source:source,mount:mount,policy:policy,work:&work)
        let body:BodyKinematics
        do throws(JointError) { body=try source.snapshot.body(input.body) } catch { throw .unknownIdentity }
        try ObservationArithmetic.numerical { () throws(NumericalError) in try work.chargeOperations(100);try work.requireStorage(48) }
        let force:Vector3,torque:Vector3,point:Vector3
        if input.frame == body.worldFrame { force=input.wrench.force;torque=input.wrench.torque;point=input.referencePoint }
        else if input.frame == body.bodyFrame {
            force=try ObservationArithmetic.core { () throws(CoreError) in try body.motion.pose.rotation.rotating(input.wrench.force) }
            torque=try ObservationArithmetic.core { () throws(CoreError) in try body.motion.pose.rotation.rotating(input.wrench.torque) }
            point=try ObservationArithmetic.core { () throws(CoreError) in try body.motion.pose.transforming(point:input.referencePoint) }
        } else { throw .invalidMounting }
        let origin=mounted.sensorToWorld.translation
        var totalForce=force
        var totalTorque=try ObservationArithmetic.core { () throws(CoreError) in try torque.adding(point.subtracting(origin).cross(force)) }
        if case .subtractBodyGravity=options.gravityCompensation {
            guard case .force=input.temporalMeaning else { throw .temporalMismatch }
            guard let gravity else { throw .staleGravity }
            try ObservationArithmetic.metadata([gravity.model.identity,gravity.field.frame.key],policy:policy,work:&work)
            guard gravity.model == source.model.stamp,gravity.timeSeconds == source.state.state.time,gravity.field.frame == body.worldFrame else { throw .staleGravity }
            // FIXME(INCOMPLETE_IMPLEMENTATION): This compensation path admits spatial rigid bodies under uniform gravity only. Distributed gradient torque/planar representations require independent mass-distribution support before successful compensation.
            guard gravity.field.gradient == .zero,
                  let record=source.model.descriptor.bodies.first(where:{$0.id == input.body}),
                  case .spatial(let spatial)=record,let inertia=spatial.inertia else { throw .unsupportedCompensation }
            let com=try ObservationArithmetic.core { () throws(CoreError) in try body.motion.pose.transforming(point:inertia.properties.centerOfMass) }
            let weight=try ObservationArithmetic.core { () throws(CoreError) in try gravity.field.accelerationAtOrigin.scaled(by:inertia.properties.mass) }
            totalForce=try ObservationArithmetic.core { () throws(CoreError) in try totalForce.subtracting(weight) }
            totalTorque=try ObservationArithmetic.core { () throws(CoreError) in try totalTorque.subtracting(com.subtracting(origin).cross(weight)) }
        }
        let inverse=mounted.sensorToWorld.rotation.conjugated()
        let sign:Double = options.sign == .intoBody ? 1 : -1
        let output=try ObservationArithmetic.core { () throws(CoreError) in
            SpatialWrench(torque:try inverse.rotating(totalTorque).scaled(by:sign),force:try inverse.rotating(totalForce).scaled(by:sign))
        }
        let impulse:Bool
        switch input.temporalMeaning { case .force:impulse=false;case .impulse:impulse=true }
        try ObservationArithmetic.check(policy)
        return PhysicalWrenchObservation(header:ObservationHeader(source:source,mount:mount,frame:mount.sensorFrame,temporal:impulse ? .instantaneousImpulse : .instantaneousContinuous),
            path:input.path,sensorToWorld:mounted.sensorToWorld,wrench:output,options:options,
            forceUnit:PhysicalDimension(length:1,mass:1,time:impulse ? -1 : -2),torqueUnit:PhysicalDimension(length:2,mass:1,time:impulse ? -1 : -2))
    }
    public func axialReaction(source:ObservationSource,mount:ObservationMount,joint:EntityID,motion:ConstrainedMotion,
                              temporal:IdentifiedPhysicalWrench.TemporalMeaning,sign:WrenchObservationOptions.Sign,
                              policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> AxialReactionObservation {
        try ObservationArithmetic.admit(source,policy:policy,work:&work)
        try ObservationArithmetic.metadata([joint.key],policy:policy,work:&work)
        try ObservationArithmetic.bind(motion,snapshot:source.snapshot,velocity:source.state.state.v,policy:policy,work:&work)
        let impulse:Bool
        switch (temporal,motion.temporalMeaning) {
        case (.force,.accelerationForce):impulse=false
        case (.impulse,.instantaneousVelocityImpulse):impulse=true
        default:throw .temporalMismatch
        }
        guard let record=source.snapshot.tree.joints.first(where:{$0.id == joint}),record.childBody == mount.body,
              let layout=source.snapshot.tree.layout.joints.first(where:{$0.joint == joint}),layout.velocities.count == 1,
              motion.generalizedReaction.count == source.snapshot.tree.layout.velocityCount,
              let anchor=source.snapshot.joints.first(where:{$0.joint == joint}) else { throw .unsupportedDecomposition }
        // FIXME(INCOMPLETE_IMPLEMENTATION): General multi-DOF, screw-coupled and bearing reactions require a physical decomposition. This callable adapter reports only one identified revolute torque or prismatic force component, not a six-axis sensor reaction.
        guard record.manifold.kind == .revolute || record.manifold.kind == .prismatic,record.manifold.orderedAxes.count == 1 else { throw .unsupportedDecomposition }
        let mounted=try ObservationArithmetic.mounted(kinematics,source:source,mount:mount,policy:policy,work:&work)
        try ObservationArithmetic.numerical { () throws(NumericalError) in try work.chargeOperations(36) }
        let axis=try ObservationArithmetic.core { () throws(CoreError) in
            try mounted.sensorToWorld.rotation.conjugated().rotating(anchor.parentAnchor.motion.pose.rotation.rotating(record.manifold.orderedAxes[0].direction))
        }
        let effort=motion.generalizedReaction[layout.velocities.start]*(sign == .intoBody ? 1 : -1)
        guard effort.isFinite else { throw .nonfinite }
        try ObservationArithmetic.check(policy)
        return AxialReactionObservation(header:ObservationHeader(source:source,mount:mount,frame:mount.sensorFrame,temporal:impulse ? .instantaneousImpulse : .instantaneousContinuous),joint:joint,
            effort:effort,effortUnit:PhysicalDimension(length:record.manifold.kind == .prismatic ? 1 : 2,mass:1,time:impulse ? -1 : -2),
            axisSensor:axis,sign:sign,reactionNullity:motion.rank.reactionNullity,retainedRowIDs:motion.rowIDs)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): This observation port has no source-bound recovered-reaction input.
    // bearingReaction remains callable only as refusal until it consumes qualified physical path/reference/equilibrium evidence;
    // existing bounded ReactionPaths producers do not grant that authority to an argument-free sensor query.
    public func bearingReaction() throws(ObservationError) -> Never { throw .unsupportedDecomposition }
}

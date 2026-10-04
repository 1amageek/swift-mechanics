
public struct ReferenceSubtreeReleaseBuilder: SubtreeReleaseBuilding {
    private let compiler:any MechanicalModelCompiling
    private let equations = RigidEquationKernel()
    public init(compiler:any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions())) {
        self.compiler=compiler
    }
    @inline(never)
    public func release(model:CompiledMechanicalModel,state:CompiledKinematicState,joint:EntityID,connector:EntityID,
                       parentAnchor:EntityID,childAnchor:EntityID,policy:SubtreeReleasePolicy,admission:DynamicsAdmission,
                       work:inout NumericalWork,dynamicsWork:inout NumericalWork) throws(TopologyReleaseFailure) -> SubtreeRelease {
        try check(policy)
        guard state.stamp == model.stamp,model.tree.bodies.count <= policy.limits.maximumBodies,model.stamp.revision < UInt64.max else { throw .staleSource }
        var metadataBytes=0
        for text in [joint.key,connector.key,parentAnchor.key,childAnchor.key] {
            for _ in text.utf8 {
                guard metadataBytes < model.policy.maximumIdentifierBytes else { throw .capacityExceeded }
                metadataBytes+=1;try TopologyArithmetic.charge(1,&work)
            }
        }
        guard connector.kind == .joint,parentAnchor.kind == .frame,childAnchor.kind == .frame,connector != joint else { throw .invalidInput }
        try TopologyArithmetic.charge(try TopologyArithmetic.numerical { () throws(NumericalError) in
            try NumericalWork.product(128,try NumericalWork.product(model.tree.bodies.count,model.tree.bodies.count))
        },&work)
        let source:KinematicSnapshot
        do throws(CompilationFailure) { source=try model.evaluate(state) } catch { throw .compilation(error) }
        guard model.tree.rootBase != .planarFloating, model.descriptor.extensions.isEmpty,
              model.descriptor.rootAuthority != .prescribedMotion,
              let selected = model.descriptor.joints.first(where: { $0.record.id == joint }),
              selected.authority != .prescribedMotion else { throw .unsupportedDomain }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Prescribed motion has no exact Runtime checkpoint continuation.
        // Release mapping must not be published until producer-authored derivative encoding and target law authority exist.
        guard state.state.prescribedAnchors.isEmpty, model.descriptor.joints.allSatisfy({ record in
            record.authority != .prescribedMotion && [record.record.parentAnchor, record.record.childAnchor].allSatisfy { anchor in
                if case .prescribed = anchor.placement { return false }; return true
            }
        }) else { throw .unsupportedDomain }
        var released = [selected.record.childBody]
        var cursor = 0
        while cursor < released.count {
            try check(policy)
            for record in model.descriptor.joints where record.record.parentBody == released[cursor] {
                try TopologyArithmetic.charge(1, &work)
                guard released.count < policy.limits.maximumBodies else { throw .capacityExceeded }
                released.append(record.record.childBody)
            }
            cursor += 1
        }
        guard model.descriptor.bodies.filter({ released.contains($0.id) }).allSatisfy({ $0.mode == .dynamic }) else { throw .unsupportedDomain }
        let leaf:BodyKinematics
        do { leaf=try source.body(selected.record.childBody) } catch { throw .invalidInput }
        let newV=try TopologyArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(model.tree.layout.velocityCount-selected.record.manifold.velocityCount,6) }
        let newQ=try TopologyArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(model.tree.layout.positionCount-selected.record.manifold.positionCount,7) }
        guard newV <= policy.limits.maximumCoordinates,newQ <= policy.limits.maximumCoordinates else { throw .capacityExceeded }
        do { try model.policy.kinematicCapacity.validating(bodyCount:model.tree.bodies.count,velocityCount:newV) } catch { throw .capacityExceeded }
        try TopologyArithmetic.numerical { () throws(NumericalError) in
            try work.requireStorage(try NumericalWork.sum(try NumericalWork.product(128,model.tree.bodies.count),try NumericalWork.product(4,try NumericalWork.sum(newQ,newV))))
        }
        try TopologyArithmetic.charge(try TopologyArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(64,model.tree.bodies.count) },&work)
        let target=try buildTarget(model:model,state:state,source:source,selected:selected,leaf:leaf,connector:connector,parentAnchor:parentAnchor,childAnchor:childAnchor)
        try check(policy)
        try compareBodies(source,target.initialSnapshot,policy:policy)
        let before=try energy(model:model,snapshot:source,velocity:state.state.v,admission:admission,work:&dynamicsWork)
        let after=try energy(model:target,snapshot:target.initialSnapshot,velocity:target.descriptor.initialState.v,admission:admission,work:&dynamicsWork)
        let conserved:Bool
        do {
            conserved=try policy.limits.kineticEnergy.contains(error:after.kineticEnergy-before.kineticEnergy,scale:before.kineticEnergy)
                && policy.limits.linearMomentum.contains(error:after.linearMomentum.subtracting(before.linearMomentum).magnitude(),scale:before.linearMomentum.magnitude())
                && policy.limits.angularMomentum.contains(error:after.angularMomentum.subtracting(before.angularMomentum).magnitude(),scale:before.angularMomentum.magnitude())
        } catch { throw .invalidInput }
        guard conserved else { throw .originalAcceptance }
        try check(policy)
        let mappings = try target.tree.layout.joints.filter { $0.joint != connector }.map { entry throws(TopologyReleaseFailure) in
            guard let old = model.tree.layout.joints.first(where: { $0.joint == entry.joint }) else { throw .staleSource }
            return SubtreeJointMapping(source: old, target: entry)
        }
        return SubtreeRelease(admission: _SubtreeReleaseAdmission(model: model, state: state, snapshot: source, target: target,
            removed: joint, connector: connector, root: leaf.body, bodies: released, mappings: mappings, before: before, after: after))
    }
    @inline(never)
    private func buildTarget(model:CompiledMechanicalModel,state:CompiledKinematicState,source:KinematicSnapshot,selected:MechanicalJoint,leaf:BodyKinematics,
                             connector:EntityID,parentAnchor:EntityID,childAnchor:EntityID) throws(TopologyReleaseFailure) -> CompiledMechanicalModel {
        var bodies:[MechanicalBody]=[],joints:[MechanicalJoint]=[]
        for body in model.descriptor.bodies {
            guard case .spatial(let spatial)=body else { throw .unsupportedDomain }
            let current:BodyKinematics
            do { current=try source.body(body.id) } catch { throw .invalidInput }
            do { bodies.append(.spatial(try BodyRecord3D(id:spatial.id,frame:spatial.frame,mode:spatial.mode,bodyToWorld:current.motion.pose,
                representations:spatial.representations,inertia:spatial.inertia))) } catch { throw .invalidInput }
        }
        for original in model.descriptor.joints {
            if original.record.id == selected.record.id {
                do { joints.append(MechanicalJoint(record:try JointRecord(id:connector,parentBody:model.descriptor.root,childBody:original.record.childBody,
                    parentAnchor:JointAnchor(frame:parentAnchor,placement:.fixed(.identity)),childAnchor:JointAnchor(frame:childAnchor,placement:.fixed(.identity)),
                    manifold:JointManifold(.sixDOF)),authority:.dynamicState)) } catch { throw .invalidInput }
            } else { joints.append(original) }
        }
        joints.sort { $0.record.id.key < $1.record.id.key }
        let proposed:KinematicTree
        do { proposed=try KinematicTree(bodies:try bodies.map({try $0.kinematicBody()}),joints:joints.map({$0.record}),root:model.descriptor.root,rootBase:model.descriptor.rootBase,
            worldFrame:model.descriptor.worldFrame,revision:model.stamp.revision+1,capacity:model.policy.kinematicCapacity) } catch { throw .invalidInput }
        var q=[Double](repeating:0,count:proposed.layout.positionCount),v=[Double](repeating:0,count:proposed.layout.velocityCount),a=v
        for i in 0..<model.tree.rootBase.positionCount { q[i] = state.state.q[i] }
        for i in 0..<model.tree.rootBase.velocityCount { v[i] = state.state.v[i]; a[i] = state.state.acceleration[i] }
        let relative: FrameMotion
        do {
            let composer = FrameMotionComposer()
            relative = try composer.composed(parent: composer.inverted(source.body(model.descriptor.root).motion), relative: leaf.motion)
        } catch { throw .invalidInput }
        for entry in proposed.layout.joints {
            if entry.joint == connector {
                let pose=relative.pose,rotation=pose.rotation,linear=relative.velocity.linear
                let angular:Vector3
                do { angular=try rotation.conjugated().rotating(relative.velocity.angular) } catch { throw .invalidInput }
                let positions=[pose.translation.x,pose.translation.y,pose.translation.z,rotation.w,rotation.x,rotation.y,rotation.z]
                let velocities=[linear.x,linear.y,linear.z,angular.x,angular.y,angular.z]
                let alpha: Vector3
                do { alpha = try rotation.conjugated().rotating(relative.acceleration.angular) } catch { throw .invalidInput }
                let linearA = relative.acceleration.linear
                let accelerations = [linearA.x,linearA.y,linearA.z,alpha.x,alpha.y,alpha.z]
                for i in 0..<7 { q[entry.positions.start+i]=positions[i] }
                for i in 0..<6 { v[entry.velocities.start+i]=velocities[i];a[entry.velocities.start+i]=accelerations[i] }
            } else {
                guard let old=model.tree.layout.joints.first(where:{$0.joint == entry.joint}),old.positions.count == entry.positions.count,old.velocities.count == entry.velocities.count else { throw .staleSource }
                for i in 0..<entry.positions.count { q[entry.positions.start+i]=state.state.q[old.positions.start+i] }
                for i in 0..<entry.velocities.count { v[entry.velocities.start+i]=state.state.v[old.velocities.start+i];a[entry.velocities.start+i]=state.state.acceleration[old.velocities.start+i] }
            }
        }
        let initial:KinematicState,descriptor:MechanicalDescriptor
        do { initial=try KinematicState(revision:proposed.revision,time:state.state.time,q:q,v:v,acceleration:a,prescribedAnchors:state.state.prescribedAnchors) }
        catch { throw .invalidInput }
        do throws(CompilationFailure) { descriptor=try MechanicalDescriptor(identity:model.stamp.identity,revision:proposed.revision,bodies:bodies,joints:joints,root:model.descriptor.root,rootBase:model.descriptor.rootBase,
            rootAuthority:model.descriptor.rootAuthority,worldFrame:model.descriptor.worldFrame,initialState:initial,representationRequirements:model.descriptor.representationRequirements,
            features:model.descriptor.features,extensions:[]) } catch { throw .compilation(error) }
        let target:CompiledMechanicalModel
        do throws(CompilationFailure) { target=try compiler.compile(descriptor,policy:model.policy) } catch { throw .compilation(error) }
        guard target.tree.layout == proposed.layout,target.descriptor == descriptor else { throw .staleSource }
        return target
    }
    private func compareBodies(_ source:KinematicSnapshot,_ target:KinematicSnapshot,policy:SubtreeReleasePolicy) throws(TopologyReleaseFailure) {
        guard source.bodies.count == target.bodies.count,source.time == target.time else { throw .staleSource }
        for original in source.bodies {
            let next:BodyKinematics
            do { next=try target.body(original.body) } catch { throw .invalidInput }
            let left=original.motion,right=next.motion
            let same:Bool
            do {
                same=try policy.limits.translation.contains(error:right.pose.translation.subtracting(left.pose.translation).magnitude(),scale:left.pose.translation.magnitude())
                    && policy.limits.rotation.contains(error:right.pose.rotation.matrix().subtracting(left.pose.rotation.matrix()).maximumMagnitude,scale:1)
                    && policy.limits.linearVelocity.contains(error:right.velocity.linear.subtracting(left.velocity.linear).magnitude(),scale:left.velocity.linear.magnitude())
                    && policy.limits.angularVelocity.contains(error:right.velocity.angular.subtracting(left.velocity.angular).magnitude(),scale:left.velocity.angular.magnitude())
            } catch { throw .invalidInput }
            guard same else { throw .staleSource }
        }
    }
    @inline(never)
    private func energy(model:CompiledMechanicalModel,snapshot:KinematicSnapshot,velocity:[Double],admission:DynamicsAdmission,work:inout NumericalWork) throws(TopologyReleaseFailure) -> MechanicalEnergy {
        var inertias:[RigidBodyInertia]=[]
        for body in snapshot.bodies {
            guard let original=model.descriptor.bodies.first(where:{$0.id == body.body}),case .spatial(let spatial)=original,let inertia=spatial.inertia else { throw .unsupportedDomain }
            do throws(DynamicsError) { inertias.append(try RigidBodyInertia(body:spatial.id,frame:spatial.frame,properties:inertia.properties)) } catch { throw .dynamics(error) }
        }
        let input:RigidDynamicsInput
        do throws(DynamicsError) { input=try RigidDynamicsInput(snapshot:snapshot,velocity:velocity,inertias:inertias,gravity:nil) } catch { throw .dynamics(error) }
        var load:LoadWork
        do { load=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0)) } catch { throw .invalidInput }
        try TopologyArithmetic.charge(1, &work)
        let before=work
        var value:MechanicalEnergy?,failure:DynamicsError?
        do throws(DynamicsError) {
            let system=try equations.assemble(input,admission:admission,loadWork:&load,work:&work)
            value=try equations.energy(system,acceleration:[Double](repeating:0,count:velocity.count),angularMomentumReference:.zero,requireComplete:true,work:&work)
        } catch { failure=error }
        guard TopologyArithmetic.preserved(before,work) else { work=before;throw .supplierWorkUnavailable }
        if let failure { throw .dynamics(failure) }
        guard let value else { throw .invalidInput };return value
    }
    private func check(_ policy:SubtreeReleasePolicy) throws(TopologyReleaseFailure) { guard !Task.isCancelled,!policy.limits.isCancelled() else { throw .cancelled } }
}

internal struct _SubtreeReleaseAdmission: Sendable {
    let model: CompiledMechanicalModel; let state: CompiledKinematicState; let snapshot: KinematicSnapshot
    let target: CompiledMechanicalModel; let removed: EntityID; let connector: EntityID; let root: EntityID
    let bodies: [EntityID]; let mappings: [SubtreeJointMapping]; let before: MechanicalEnergy; let after: MechanicalEnergy
    fileprivate init(model: CompiledMechanicalModel, state: CompiledKinematicState, snapshot: KinematicSnapshot,
                     target: CompiledMechanicalModel, removed: EntityID, connector: EntityID, root: EntityID,
                     bodies: [EntityID], mappings: [SubtreeJointMapping], before: MechanicalEnergy, after: MechanicalEnergy) {
        self.model=model; self.state=state; self.snapshot=snapshot; self.target=target; self.removed=removed
        self.connector=connector; self.root=root; self.bodies=bodies; self.mappings=mappings; self.before=before; self.after=after
    }
}

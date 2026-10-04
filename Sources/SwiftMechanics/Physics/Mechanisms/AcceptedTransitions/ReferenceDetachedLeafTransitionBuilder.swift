
public struct ReferenceDetachedLeafTransitionBuilder: DetachedLeafTransitionBuilding {
    private let compiler:any MechanicalModelCompiling
    private let equations:any RigidEquationComputing
    public init(compiler:any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions:NoMechanicalExtensions()),equations:any RigidEquationComputing = RigidEquationKernel()) {
        self.compiler=compiler;self.equations=equations
    }
    @inline(never)
    public func detach(model:CompiledMechanicalModel,state:CompiledKinematicState,joint:EntityID,connector:EntityID,
                       parentAnchor:EntityID,childAnchor:EntityID,policy:DetachedLeafPolicy,admission:DynamicsAdmission,
                       work:inout NumericalWork,dynamicsWork:inout NumericalWork) throws(MechanismError) -> DetachedLeafTransition {
        try check(policy)
        guard state.stamp == model.stamp,model.tree.bodies.count <= policy.maximumBodies,model.stamp.revision < UInt64.max else { throw .staleBinding }
        var metadataBytes=0
        for text in [joint.key,connector.key,parentAnchor.key,childAnchor.key] {
            for _ in text.utf8 {
                guard metadataBytes < model.policy.maximumIdentifierBytes else { throw .capacityExceeded }
                metadataBytes+=1;try MechanismArithmetic.charge(1,&work)
            }
        }
        guard connector.kind == .joint,parentAnchor.kind == .frame,childAnchor.kind == .frame,connector != joint else { throw .invalidInput }
        let source:KinematicSnapshot
        do throws(CompilationFailure) { source=try model.evaluate(state) } catch { throw .compilation(error) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Actual release currently supports a direct-root spatial leaf under identity stationary root/anchors only. General subtree/loop cut release and active extension/law migration require producer-authored mapping and physical acceptance before success.
        guard model.tree.rootBase == .fixed,model.descriptor.rootAuthority == .fixed,model.descriptor.extensions.isEmpty,
              source.bodies[0].motion.pose == .identity,source.bodies[0].motion.velocity == SpatialMotion(angular:.zero,linear:.zero),
              let selected=model.descriptor.joints.first(where:{$0.record.id == joint}),selected.authority == .dynamicState,
              selected.record.parentBody == model.descriptor.root,
              !model.descriptor.joints.contains(where:{$0.record.parentBody == selected.record.childBody}) else { throw .unsupportedTopologyReplacement }
        for anchor in [selected.record.parentAnchor,selected.record.childAnchor] {
            guard case .fixed(let pose)=anchor.placement,pose == .identity else { throw .unsupportedTopologyReplacement }
        }
        guard selected.record.manifold.kind == .revolute || selected.record.manifold.kind == .prismatic || selected.record.manifold.kind == .fixed else { throw .unsupportedTopologyReplacement }
        let leaf:BodyKinematics
        do { leaf=try source.body(selected.record.childBody) } catch { throw .invalidInput }
        let newV=try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(model.tree.layout.velocityCount-selected.record.manifold.velocityCount,6) }
        let newQ=try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(model.tree.layout.positionCount-selected.record.manifold.positionCount,7) }
        guard newV <= policy.maximumCoordinates,newQ <= policy.maximumCoordinates else { throw .capacityExceeded }
        do { try model.policy.kinematicCapacity.validating(bodyCount:model.tree.bodies.count,velocityCount:newV) } catch { throw .capacityExceeded }
        try MechanismArithmetic.numerical { () throws(NumericalError) in
            try work.requireStorage(try NumericalWork.sum(try NumericalWork.product(128,model.tree.bodies.count),try NumericalWork.product(4,try NumericalWork.sum(newQ,newV))))
        }
        try MechanismArithmetic.charge(try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(64,model.tree.bodies.count) },&work)
        let target=try buildTarget(model:model,state:state,source:source,selected:selected,leaf:leaf,connector:connector,parentAnchor:parentAnchor,childAnchor:childAnchor)
        try check(policy)
        try compareBodies(source,target.initialSnapshot,policy:policy)
        let before=try energy(model:model,snapshot:source,velocity:state.state.v,admission:admission,work:&dynamicsWork)
        let after=try energy(model:target,snapshot:target.initialSnapshot,velocity:target.descriptor.initialState.v,admission:admission,work:&dynamicsWork)
        let conserved:Bool
        do {
            conserved=try policy.kineticEnergy.contains(error:after.kineticEnergy-before.kineticEnergy,scale:before.kineticEnergy)
                && policy.linearMomentum.contains(error:after.linearMomentum.subtracting(before.linearMomentum).magnitude(),scale:before.linearMomentum.magnitude())
                && policy.angularMomentum.contains(error:after.angularMomentum.subtracting(before.angularMomentum).magnitude(),scale:before.angularMomentum.magnitude())
        } catch { throw .invalidInput }
        guard conserved else { throw .originalMomentum(residual:abs(after.kineticEnergy-before.kineticEnergy)) }
        try check(policy)
        return DetachedLeafTransition(source:state,snapshot:source,target:target,physical:target.descriptor.initialState,removed:joint,connector:connector,body:leaf.body,sourceEnergy:before,targetEnergy:after)
    }
    @inline(never)
    private func buildTarget(model:CompiledMechanicalModel,state:CompiledKinematicState,source:KinematicSnapshot,selected:MechanicalJoint,leaf:BodyKinematics,
                             connector:EntityID,parentAnchor:EntityID,childAnchor:EntityID) throws(MechanismError) -> CompiledMechanicalModel {
        var bodies:[MechanicalBody]=[],joints:[MechanicalJoint]=[]
        for body in model.descriptor.bodies {
            guard case .spatial(let spatial)=body else { throw .unsupportedTopologyReplacement }
            let current:BodyKinematics
            do { current=try source.body(body.id) } catch { throw .invalidShape }
            do { bodies.append(.spatial(try BodyRecord3D(id:spatial.id,frame:spatial.frame,mode:spatial.mode,bodyToWorld:current.motion.pose,
                representations:spatial.representations,inertia:spatial.inertia))) } catch { throw .invalidInput }
        }
        for original in model.descriptor.joints {
            if original.record.id == selected.record.id {
                do { joints.append(MechanicalJoint(record:try JointRecord(id:connector,parentBody:original.record.parentBody,childBody:original.record.childBody,
                    parentAnchor:JointAnchor(frame:parentAnchor,placement:.fixed(.identity)),childAnchor:JointAnchor(frame:childAnchor,placement:.fixed(.identity)),
                    manifold:JointManifold(.sixDOF)),authority:.dynamicState)) } catch { throw .invalidInput }
            } else { joints.append(original) }
        }
        joints.sort { $0.record.id.key < $1.record.id.key }
        let proposed:KinematicTree
        do { proposed=try KinematicTree(bodies:try bodies.map({try $0.kinematicBody()}),joints:joints.map({$0.record}),root:model.descriptor.root,rootBase:.fixed,
            worldFrame:model.descriptor.worldFrame,revision:model.stamp.revision+1,capacity:model.policy.kinematicCapacity) } catch { throw .invalidInput }
        var q=[Double](repeating:0,count:proposed.layout.positionCount),v=[Double](repeating:0,count:proposed.layout.velocityCount),a=v
        for entry in proposed.layout.joints {
            if entry.joint == connector {
                let pose=leaf.motion.pose,rotation=pose.rotation,linear=leaf.motion.velocity.linear
                let angular:Vector3
                do { angular=try rotation.conjugated().rotating(leaf.motion.velocity.angular) } catch { throw .invalidInput }
                let positions=[pose.translation.x,pose.translation.y,pose.translation.z,rotation.w,rotation.x,rotation.y,rotation.z]
                let velocities=[linear.x,linear.y,linear.z,angular.x,angular.y,angular.z]
                for i in 0..<7 { q[entry.positions.start+i]=positions[i] }
                for i in 0..<6 { v[entry.velocities.start+i]=velocities[i] }
            } else {
                guard let old=model.tree.layout.joints.first(where:{$0.joint == entry.joint}),old.positions.count == entry.positions.count,old.velocities.count == entry.velocities.count else { throw .staleBinding }
                for i in 0..<entry.positions.count { q[entry.positions.start+i]=state.state.q[old.positions.start+i] }
                for i in 0..<entry.velocities.count { v[entry.velocities.start+i]=state.state.v[old.velocities.start+i];a[entry.velocities.start+i]=state.state.acceleration[old.velocities.start+i] }
            }
        }
        let initial:KinematicState,descriptor:MechanicalDescriptor
        do { initial=try KinematicState(revision:proposed.revision,time:state.state.time,q:q,v:v,acceleration:a,prescribedAnchors:state.state.prescribedAnchors) }
        catch { throw .invalidInput }
        do throws(CompilationFailure) { descriptor=try MechanicalDescriptor(identity:model.stamp.identity,revision:proposed.revision,bodies:bodies,joints:joints,root:model.descriptor.root,rootBase:.fixed,
            rootAuthority:.fixed,worldFrame:model.descriptor.worldFrame,initialState:initial,representationRequirements:model.descriptor.representationRequirements,
            features:model.descriptor.features,extensions:[]) } catch { throw .compilation(error) }
        let target:CompiledMechanicalModel
        do throws(CompilationFailure) { target=try compiler.compile(descriptor,policy:model.policy) } catch { throw .compilation(error) }
        guard target.tree.layout == proposed.layout,target.descriptor == descriptor else { throw .staleBinding }
        return target
    }
    private func compareBodies(_ source:KinematicSnapshot,_ target:KinematicSnapshot,policy:DetachedLeafPolicy) throws(MechanismError) {
        guard source.bodies.count == target.bodies.count,source.time == target.time else { throw .staleBinding }
        for original in source.bodies {
            let next:BodyKinematics
            do { next=try target.body(original.body) } catch { throw .invalidInput }
            let left=original.motion,right=next.motion
            let same:Bool
            do {
                same=try policy.translation.contains(error:right.pose.translation.subtracting(left.pose.translation).magnitude(),scale:left.pose.translation.magnitude())
                    && policy.rotation.contains(error:right.pose.rotation.matrix().subtracting(left.pose.rotation.matrix()).maximumMagnitude,scale:1)
                    && policy.linearVelocity.contains(error:right.velocity.linear.subtracting(left.velocity.linear).magnitude(),scale:left.velocity.linear.magnitude())
                    && policy.angularVelocity.contains(error:right.velocity.angular.subtracting(left.velocity.angular).magnitude(),scale:left.velocity.angular.magnitude())
            } catch { throw .invalidInput }
            guard same else { throw .staleBinding }
        }
    }
    @inline(never)
    private func energy(model:CompiledMechanicalModel,snapshot:KinematicSnapshot,velocity:[Double],admission:DynamicsAdmission,work:inout NumericalWork) throws(MechanismError) -> MechanicalEnergy {
        var inertias:[RigidBodyInertia]=[]
        for body in snapshot.bodies {
            guard let original=model.descriptor.bodies.first(where:{$0.id == body.body}),case .spatial(let spatial)=original,let inertia=spatial.inertia else { throw .unsupportedTopologyReplacement }
            do throws(DynamicsError) { inertias.append(try RigidBodyInertia(body:spatial.id,frame:spatial.frame,properties:inertia.properties)) } catch { throw .dynamics(error) }
        }
        let input:RigidDynamicsInput
        do throws(DynamicsError) { input=try RigidDynamicsInput(snapshot:snapshot,velocity:velocity,inertias:inertias,gravity:nil) } catch { throw .dynamics(error) }
        var load:LoadWork
        do { load=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0)) } catch { throw .invalidInput }
        try MechanismArithmetic.charge(1,&work)
        let before=work
        var value:MechanicalEnergy?,failure:DynamicsError?
        do throws(DynamicsError) {
            let system=try equations.assemble(input,admission:admission,loadWork:&load,work:&work)
            value=try equations.energy(system,acceleration:[Double](repeating:0,count:velocity.count),angularMomentumReference:.zero,requireComplete:true,work:&work)
        } catch { failure=error }
        guard MechanismArithmetic.preserved(before,work) else { work=before;throw .supplierLedgerReplaced }
        if let failure { throw .dynamics(failure) }
        guard let value else { throw .invalidShape };return value
    }
    private func check(_ policy:DetachedLeafPolicy) throws(MechanismError) { guard !Task.isCancelled,!policy.isCancelled() else { throw .cancelled } }
}

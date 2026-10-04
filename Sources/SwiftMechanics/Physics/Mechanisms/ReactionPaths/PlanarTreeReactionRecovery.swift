public struct PlanarTreeReactionRecovery: PlanarTreeReactionRecovering {
    private let equations:any PhysicalRigidEquationComputing
    private let gravity:any GravityEvaluating
    public init(equations:any PhysicalRigidEquationComputing=RigidEquationKernel(),gravity:any GravityEvaluating=GravityEvaluator()) {
        self.equations=equations;self.gravity=gravity
    }
    @inline(never)
    public func recover(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],topology:TreeReactionTopology,
                        outputFrame:EntityID,policy:TreeReactionPolicy,loadWork:inout LoadWork,
                        work:inout NumericalWork) throws(ReactionPathError)->PlanarTreeReactionReport {
        try PlanarReactionArithmetic.check(policy)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Unrepresented loops, mesh paths and bearing splits have no allocation contract here. This planar tree port must refuse them until identified original loads and independent allocation evidence exist.
        guard topology == .completeTree else { throw .unrepresentedConnections }
        let context=try PlanarReactionContext(system),snapshot=context.input.snapshot,tree=snapshot.tree
        let count=snapshot.bodies.count,n=system.velocityCount
        guard count <= policy.maximumBodies,tree.joints.count <= policy.maximumJoints,
              context.input.bodyWrenches.count <= policy.maximumBodyLoads else { throw .capacityExceeded }
        guard acceleration.count == n,policy.generalizedForceScales.count == n else { throw .invalidShape }
        guard acceleration.allSatisfy({$0.isFinite}) else { throw .invalidInput }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Generalized-only loads do not identify body force/couple allocation. This path requires physically identified original body loads before successful recovery.
        guard context.input.generalizedForces.allSatisfy({$0.values.allSatisfy({$0 == 0})}) else { throw .nonuniqueGeneralizedAllocation }
        let pose:RigidTransform
        do { pose=try snapshot.frame(outputFrame).motion.pose } catch { throw .joints(error) }
        guard pose.rotation.x == 0,pose.rotation.y == 0 else { throw .dynamics(.nonplanarInput) }
        try PlanarReactionArithmetic.numeric { () throws(NumericalError) in
            let local=try NumericalWork.sum(128,NumericalWork.sum(NumericalWork.product(64,count),NumericalWork.sum(NumericalWork.product(32,tree.joints.count),NumericalWork.product(8,n))))
            try work.requireStorage(NumericalWork.sum(system.scalarStorage,local))
        }
        var net=[PlanarReactionWrench](repeating:PlanarReactionArithmetic.zero,count:count),parent=[Int](repeating:-1,count:count)
        var generalized=[Double](repeating:0,count:n),magnitude=[Double](repeating:0,count:n)
        for joint in tree.joints {
            try PlanarReactionArithmetic.check(policy);try PlanarReactionArithmetic.charge(2,&work)
            let child=try bodyIndex(tree,joint.childBody),ancestor=try bodyIndex(tree,joint.parentBody)
            guard child > ancestor,parent[child] == -1 else { throw .invalidSupplierEvidence };parent[child]=ancestor
        }
        for i in 0..<count {
            try PlanarReactionArithmetic.check(policy);try PlanarReactionArithmetic.charge(128,&work)
            let state=snapshot.bodies[i],point=state.motion.pose.translation
            let original=try originalBody(context,body:state.body,acceleration:acceleration,point:point,policy:policy,work:&work)
            net[i]=try PlanarReactionArithmetic.shifted(original,from:point,to:.zero)
            if let field=context.input.gravity {
                let properties=context.input.inertias[i].properties
                let com=try PlanarReactionArithmetic.core { () throws(CoreError) in try state.motion.pose.transforming(point:Vector3(properties.centerX,properties.centerY,0)) }
                let weight=try originalGravity(field,body:state.body,point:com,mass:properties.mass,loadWork:&loadWork)
                net[i]=try PlanarReactionArithmetic.subtract(net[i],weight)
            }
        }
        for load in context.input.bodyWrenches {
            try PlanarReactionArithmetic.check(policy);try PlanarReactionArithmetic.charge(256,&work)
            let state=snapshot.bodies[try bodyIndex(tree,load.body)]
            let original=try originalLoad(load,state:state)
            let world=try PlanarReactionArithmetic.shifted(original,from:state.motion.pose.translation,to:.zero)
            let i=try bodyIndex(tree,load.body);net[i]=try PlanarReactionArithmetic.subtract(net[i],world)
        }
        for i in 0..<count {
            try PlanarReactionArithmetic.check(policy);try PlanarReactionArithmetic.charge(64,&work)
            let body=try PlanarReactionArithmetic.shifted(net[i],from:.zero,to:snapshot.bodies[i].motion.pose.translation)
            let columns:ArraySlice<SpatialMotion>
            do { columns=try snapshot.geometricColumns(body:snapshot.bodies[i].body) } catch { throw .joints(error) }
            for (k,column) in columns.enumerated() {
                try PlanarReactionArithmetic.check(policy);try PlanarReactionArithmetic.charge(32,&work)
                let linear=try PlanarReactionArithmetic.finite(PlanarReactionArithmetic.finite(body.forceX*column.linear.x)+PlanarReactionArithmetic.finite(body.forceY*column.linear.y))
                let value=try PlanarReactionArithmetic.finite(linear+PlanarReactionArithmetic.finite(body.momentZ*column.angular.z))
                generalized[k]=try PlanarReactionArithmetic.finite(generalized[k]+value)
                magnitude[k]=try PlanarReactionArithmetic.finite(magnitude[k]+abs(value))
            }
        }
        var maximum=0.0
        for k in 0..<n {
            try PlanarReactionArithmetic.check(policy);try PlanarReactionArithmetic.charge(4,&work)
            let value=try PlanarReactionArithmetic.finite(generalized[k]/policy.generalizedForceScales[k])
            let scale=try PlanarReactionArithmetic.finite(magnitude[k]/policy.generalizedForceScales[k])
            guard try PlanarReactionArithmetic.core({ () throws(CoreError) in try policy.generalizedTolerance.contains(error:value,scale:scale) }) else { throw .originalGeneralizedResidual(index:k,scaledValue:value) }
            maximum=max(maximum,abs(value))
        }
        var subtree=net
        if count > 1 {
            for i in stride(from:count-1,through:1,by:-1) {
                try PlanarReactionArithmetic.check(policy);try PlanarReactionArithmetic.charge(12,&work)
                guard parent[i] >= 0 else { throw .invalidSupplierEvidence }
                subtree[parent[i]]=try PlanarReactionArithmetic.add(subtree[parent[i]],subtree[i])
            }
        }
        var balance=subtree
        for i in 1..<count {
            try PlanarReactionArithmetic.check(policy);try PlanarReactionArithmetic.charge(12,&work)
            balance[parent[i]]=try PlanarReactionArithmetic.subtract(balance[parent[i]],subtree[i])
        }
        for i in 0..<count {
            try PlanarReactionArithmetic.check(policy);try PlanarReactionArithmetic.charge(24,&work)
            guard try PlanarReactionArithmetic.agrees(balance[i],net[i],policy:policy) else { throw .originalBodyBalance(body:snapshot.bodies[i].body) }
        }
        var results:[PlanarJointReactionWrench]=[];results.reserveCapacity(tree.joints.count)
        for joint in tree.joints {
            try PlanarReactionArithmetic.check(policy);try PlanarReactionArithmetic.charge(384,&work)
            let index=try bodyIndex(tree,joint.childBody),point:Vector3
            do { point=try snapshot.frame(joint.childAnchor.frame).motion.pose.translation } catch { throw .joints(error) }
            let wrench=try PlanarReactionArithmetic.converted(subtree[index],referenceWorld:point,pose:pose)
            let framed=try PlanarReactionArithmetic.core { () throws(CoreError) in try pose.inverted().transforming(point:point) }
            results.append(PlanarJointReactionWrench(joint:joint.id,parentBody:joint.parentBody,childBody:joint.childBody,frame:outputFrame,
                referencePoint:framed,referencePointWorld:point,parentOnChild:wrench,childOnParent:PlanarReactionArithmetic.negated(wrench),timeSeconds:snapshot.time,revision:tree.revision))
        }
        try PlanarReactionArithmetic.check(policy);try PlanarReactionArithmetic.charge(384,&work)
        let support:PlanarRootSupportWrench?
        if tree.rootBase == .fixed {
            let point=snapshot.bodies[0].motion.pose.translation,wrench=try PlanarReactionArithmetic.converted(subtree[0],referenceWorld:point,pose:pose)
            let framed=try PlanarReactionArithmetic.core { () throws(CoreError) in try pose.inverted().transforming(point:point) }
            support=PlanarRootSupportWrench(rootBody:snapshot.bodies[0].body,frame:outputFrame,referencePoint:framed,referencePointWorld:point,
                supportOnRoot:wrench,rootOnSupport:PlanarReactionArithmetic.negated(wrench),timeSeconds:snapshot.time,revision:tree.revision)
        } else {
            guard try PlanarReactionArithmetic.agrees(subtree[0],PlanarReactionArithmetic.zero,policy:policy) else { throw .originalBodyBalance(body:snapshot.bodies[0].body) };support=nil
        }
        try PlanarReactionArithmetic.check(policy)
        return PlanarTreeReactionReport(system:system,joints:results,support:support,maximumScaledOriginalGeneralizedResidual:maximum,numericalWork:work,loadWork:loadWork,topologyAssumption:topology)
    }

    @inline(never)
    internal func originalBody(_ context:PlanarReactionContext,body:EntityID,acceleration:[Double],point:Vector3,
                              policy:TreeReactionPolicy,work:inout NumericalWork) throws(ReactionPathError)->PlanarReactionWrench {
        let before=work,evidence:BodyWrenchEvidence
        do { evidence=try equations.inertialWrench(context.system,body:body,acceleration:acceleration,referencePointWorld:point,work:&work) }
        catch { try PlanarReactionArithmetic.ledger(before,&work);throw .dynamics(error) }
        try PlanarReactionArithmetic.ledger(before,&work)
        guard evidence.body == body,evidence.frame == context.input.snapshot.tree.worldFrame,evidence.referencePoint == point else { throw .invalidSupplierEvidence }
        let original:BodyWrenchEvidence
        do { original=try RigidEquationKernel().inertialWrench(context.system,body:body,acceleration:acceleration,referencePointWorld:point,work:&work) }
        catch { throw .dynamics(error) }
        let supplied=try PlanarReactionArithmetic.reduced(evidence.wrench),canonical=try PlanarReactionArithmetic.reduced(original.wrench)
        guard try PlanarReactionArithmetic.agrees(supplied,canonical,policy:policy) else { throw .invalidSupplierEvidence }
        return canonical
    }
    @inline(never)
    internal func originalGravity(_ field:AffineGravity,body:EntityID,point:Vector3,mass:Double,loadWork:inout LoadWork) throws(ReactionPathError)->PlanarReactionWrench {
        do { try loadWork.charge(1) } catch { throw .loads(error) }
        let before=loadWork;var supplier=loadWork
        let response:GravityResponse,sample:GravitySample
        do { sample=try GravitySample(point:point,mass:mass) } catch { throw .loads(error) }
        do { response=try gravity.point(field,body:body,sample:sample,work:&supplier) }
        catch { try PlanarReactionArithmetic.merge(before,supplier:supplier,into:&loadWork);throw .loads(error) }
        try PlanarReactionArithmetic.merge(before,supplier:supplier,into:&loadWork)
        let original:GravityResponse
        do { original=try GravityEvaluator().point(field,body:body,sample:sample,work:&loadWork) } catch { throw .loads(error) }
        guard response == original else { throw .invalidSupplierEvidence }
        let wrench:SpatialWrench
        do { wrench=try original.load.wrench(about:.zero) } catch { throw .loads(error) }
        return try PlanarReactionArithmetic.reduced(wrench)
    }
    internal func originalLoad(_ load:BodyWrenchContribution,state:BodyKinematics) throws(ReactionPathError)->PlanarReactionWrench {
        let force:Vector3,torque:Vector3,point:Vector3
        if load.frame == state.worldFrame { force=load.wrench.force;torque=load.wrench.torque;point=load.referencePoint }
        else if load.frame == state.bodyFrame {
            force=try PlanarReactionArithmetic.core { () throws(CoreError) in try state.motion.pose.rotation.rotating(load.wrench.force) }
            torque=try PlanarReactionArithmetic.core { () throws(CoreError) in try state.motion.pose.rotation.rotating(load.wrench.torque) }
            point=try PlanarReactionArithmetic.core { () throws(CoreError) in try state.motion.pose.transforming(point:load.referencePoint) }
        } else { throw .dynamics(.frameMismatch) }
        let shifted=try PlanarReactionArithmetic.core { () throws(CoreError) in
            SpatialWrench(torque:try torque.adding(point.subtracting(state.motion.pose.translation).cross(force)),force:force)
        }
        return try PlanarReactionArithmetic.reduced(shifted)
    }
    private func bodyIndex(_ tree:KinematicTree,_ body:EntityID) throws(ReactionPathError)->Int {
        do { return try tree.bodyIndex(body) } catch { throw .joints(error) }
    }
}

public struct PlanarPrescribedRootReactionRecovery: PlanarPrescribedRootReactionRecovering {
    private typealias A = PlanarPrescribedRootReactionArithmetic
    private let equations: any PhysicalRigidEquationComputing
    private let physical: PlanarTreeReactionRecovery
    public init(equations: any PhysicalRigidEquationComputing = RigidEquationKernel(),
                gravity: any GravityEvaluating = GravityEvaluator()) {
        self.equations=equations;physical=PlanarTreeReactionRecovery(equations:equations,gravity:gravity)
    }
    @inline(never)
    public func recover(_ input: PlanarPrescribedRootReactionInput, outputFrame: EntityID,
                        policy: PlanarPrescribedRootReactionPolicy, loadWork: inout LoadWork,
                        work: inout NumericalWork) throws(PlanarPrescribedRootReactionError) -> PlanarPrescribedRootReactionReport {
        let context=try prepare(input,policy:policy,work:&work)
        let full=try originalForce(context,policy:policy,work:&work)
        return try recoverPhysical(context,full:full,outputFrame:outputFrame,policy:policy,loadWork:&loadWork,work:&work)
    }

    @inline(never)
    private func prepare(_ input: PlanarPrescribedRootReactionInput, policy: PlanarPrescribedRootReactionPolicy,
                         work: inout NumericalWork) throws(PlanarPrescribedRootReactionError) -> PlanarPrescribedRootReactionContext {
        try A.check(policy)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Prescribed spatial/free roots, named supports and original loop rows have no allocation contract in this additive planar tree port. They require separate physical proof before success.
        guard input.geometry.model.tree.rootBase == .planarFloating,
              input.geometry.model.descriptor.rootAuthority == .prescribedMotion,
              let binding=input.geometry.prescribedRoot,input.geometry.prescribedMotion == nil,
              input.state.prescribedAnchors.isEmpty,input.geometry.relations.isEmpty,input.geometry.rowIDs.isEmpty,
              input.constraint.geometry.rowIDs.isEmpty,input.constraint.geometry.rows.isEmpty,
              input.constraint.geometry.drift.isEmpty,input.constraint.geometry.accelerationBias.isEmpty else { throw .unsupportedSupportDomain }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Unrepresented physical paths and bearing splits cannot be inferred from tree shape. The caller must declare complete physical tree topology before this port can succeed.
        guard input.topology == .completeTree else { throw .unrepresentedConnections }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Impulse-to-force conversion has no time-window authority here; only original continuous acceleration-force motion is recoverable.
        guard input.motion.motion.temporalMeaning == .accelerationForce else { throw .unsupportedTemporalMeaning }
        let n=input.dynamics.velocityCount,k=binding.knownCoordinates.count,b=input.dynamics.input.snapshot.bodies.count
        guard n <= policy.mechanism.maximumCoordinates,n <= policy.geometry.maximumCoordinates,
              n <= policy.mechanism.constraints.evaluation.maximumCoordinates,k <= policy.mechanism.maximumRows,
              k <= policy.mechanism.constraints.evaluation.maximumRows,k <= policy.geometry.maximumRows,
              b <= policy.tree.maximumBodies,input.geometry.model.tree.bodies.count <= policy.tree.maximumBodies,
              input.geometry.model.tree.joints.count <= policy.tree.maximumJoints,
              input.dynamics.input.snapshot.tree.joints.count <= policy.tree.maximumJoints,
              input.dynamics.input.bodyWrenches.count <= policy.tree.maximumBodyLoads else { throw .capacityExceeded }
        guard k == 3,n >= k,input.originalDrive.count == n,input.motion.motion.values.count == n,
              input.motion.motion.generalizedReaction.count == n,input.motion.motion.rowMultipliers.count == k,
              policy.tree.generalizedForceScales.count == n else { throw .invalidShape }
        guard input.originalDrive.allSatisfy({$0.isFinite}),input.motion.motion.values.allSatisfy({$0.isFinite}),
              input.motion.motion.rowMultipliers.allSatisfy({$0.isFinite}),input.motion.motion.generalizedReaction.allSatisfy({$0.isFinite}) else { throw .invalidInput }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Generalized-only loads/drive lack physical body allocation. Physically identified original force/couple inputs are required before successful support/cut recovery.
        guard input.originalDrive.allSatisfy({$0 == 0}),input.dynamics.input.generalizedForces.allSatisfy({$0.values.allSatisfy({$0 == 0})}) else { throw .unallocatableGeneralizedLoad }
        for joint in input.geometry.model.tree.joints {
            for anchor in [joint.parentAnchor,joint.childAnchor] {
                guard case .fixed = anchor.placement else { throw .unsupportedSupportDomain }
            }
        }
        guard input.motion.system === input.constraint.system,input.dynamics.input.dimension == .planar,
              input.motion.motion.sourceVelocity == input.state.v,input.dynamics.input.velocity == input.state.v,
              input.motion.motion.time.bitPattern == input.state.time.bitPattern,
              input.dynamics.input.snapshot.time.bitPattern == input.state.time.bitPattern,
              input.motion.motion.frame == input.geometry.model.tree.worldFrame,
              input.motion.motion.basis == input.geometry.model.tree.layout,
              A.layout(input.motion.motion.layout,input.geometry.layout),
              input.geometry.layout.scales == policy.mechanism.dynamics.coordinateScales,
              input.geometry.layout.timeScale == policy.mechanism.dynamics.timeScale else { throw .staleSource }
        try A.numeric { () throws(NumericalError) in
            let width=try NumericalWork.sum(n,1)
            let local=try NumericalWork.sum(NumericalWork.product(2048,NumericalWork.product(b,width)),NumericalWork.product(128,n))
            try work.requireStorage(NumericalWork.sum(input.geometry.scalarStorage,NumericalWork.sum(input.dynamics.scalarStorage,local)))
        }
        try A.charge(128,&work)
        let original: HolonomicGeometrySample
        do throws(GeometricConstraintError) {
            let supplied=try GeometricRelationEvaluator().evaluate(input.geometry,state:input.state,policy:policy.geometry,work:&work)
            original=try GeometricOriginalAcceptance.validatedSample(supplied,system:input.geometry,state:input.state,
                tolerance:0,policy:policy.geometry,work:&work)
            for snapshot in [input.dynamics.input.snapshot,input.motion.motion.sourceSnapshot] {
                guard snapshot.time.bitPattern == original.snapshot.time.bitPattern else { throw .staleSource }
                let candidate=HolonomicGeometrySample(source:input.state,snapshot:snapshot,metadata:original.metadata,
                    values:original.values,velocity:original.velocity,alignmentResiduals:original.alignmentResiduals)
                try GeometricOriginalAcceptance.validate(candidate,system:input.geometry,state:input.state,tolerance:0,policy:policy.geometry,work:&work)
            }
        } catch { throw .geometry(error) }
        let base: PrescribedBaseMotionSample
        do throws(PrescribedMotionError) {
            base=try OriginalPrescribedBaseMotionAcceptance.validated(input.constraint.base,program:binding.program,
                time:input.state.time,policy:binding.program.policy,work:&work)
        } catch { throw .motion(error) }
        let constraint: PrescribedRootConstraint
        do throws(MechanismError) {
            constraint=try PrescribedRootConstraint(system:input.dynamics,geometry:original.velocity,base:base,
                rowIDs:binding.rowIDs,policy:policy.mechanism,work:&work)
        } catch { throw .mechanism(error) }
        guard A.equal(input.constraint.geometry,original.velocity),A.equal(input.constraint.sample,constraint.sample),
              input.constraint.knownCoordinates == binding.knownCoordinates,input.constraint.dynamicCoordinates == binding.dynamicCoordinates,
              input.motion.motion.rowIDs == constraint.sample.rowIDs else { throw .staleSource }
        let rank: ConstraintRankEvidence
        do throws(ConstraintError) { rank=try WeightedConstraintAssembler().rank(constraint.sample,policy:policy.mechanism.constraints,work:&work) }
        catch { throw .constraint(error) }
        let supplied=input.motion.motion.rank
        guard rank.rank == k,rank.reactionNullity == 0,supplied.rank == rank.rank,
              supplied.independentRows == rank.independentRows,supplied.dependentRowIDs == rank.dependentRowIDs,
              supplied.reactionNullity == rank.reactionNullity else { throw .invalidRankEvidence }
        var reaction=[Double](repeating:0,count:n)
        for row in 0..<k {
            try A.check(policy);try A.charge(32,&work)
            guard input.motion.motion.values[row].bitPattern == base.a[row].bitPattern else { throw .originalRootRow(row:binding.rowIDs[row]) }
            var v=constraint.sample.drift[row],a=constraint.sample.accelerationBias[row]
            for i in 0..<n {
                try A.charge(16,&work)
                let entry=constraint.sample.rows[row*n+i],s=constraint.sample.layout.scales[i],t=constraint.sample.layout.timeScale
                v=try A.finite(v+entry*input.state.v[i]*t/s)
                a=try A.finite(a+entry*input.motion.motion.values[i]*t*t/s)
                reaction[i]=try A.finite(reaction[i]+entry*input.motion.motion.rowMultipliers[row]/s)
            }
            guard abs(v) <= policy.mechanism.originalTolerance,abs(a) <= policy.mechanism.originalTolerance else { throw .originalRootRow(row:binding.rowIDs[row]) }
        }
        for i in 0..<n {
            try A.check(policy);try A.charge(8,&work)
            do throws(PlanarPrescribedRootReactionError) { _=try A.residual(reaction[i],input.motion.motion.generalizedReaction[i],index:i,policy:policy.tree) }
            catch { throw .originalGeneralizedReaction(index:i) }
        }
        let physical=try A.tree { () throws(ReactionPathError) in try PlanarReactionContext(input.dynamics) }
        try A.check(policy)
        return PlanarPrescribedRootReactionContext(source:input,physical:physical,original:original,constraint:constraint,
            rank:rank,reaction:reaction,rootEffort:Array(reaction.prefix(k)))
    }

    @inline(never)
    private func originalForce(_ context: PlanarPrescribedRootReactionContext, policy: PlanarPrescribedRootReactionPolicy,
                               work: inout NumericalWork) throws(PlanarPrescribedRootReactionError) -> [Double] {
        try A.check(policy);try A.charge(1,&work)
        let before=work;var supplied=[Double](repeating:0,count:context.physical.system.velocityCount)
        do throws(DynamicsError) {
            try equations.originalInertialForce(context.physical.system,acceleration:context.source.motion.motion.values,
                includeBias:true,into:&supplied,work:&work)
        } catch {
            try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.ledger(before,&work) };throw .dynamics(error)
        }
        try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.ledger(before,&work) }
        var canonical=[Double](repeating:0,count:context.physical.system.velocityCount)
        do throws(DynamicsError) {
            try RigidEquationKernel().originalInertialForce(context.physical.system,acceleration:context.source.motion.motion.values,
                includeBias:true,into:&canonical,work:&work)
        } catch { throw .dynamics(error) }
        guard supplied.count == canonical.count else { throw .invalidSupplierEvidence }
        for i in canonical.indices {
            try A.check(policy);try A.charge(8,&work)
            do throws(PlanarPrescribedRootReactionError) { _=try A.residual(supplied[i],canonical[i],index:i,policy:policy.tree) }
            catch { throw .invalidSupplierEvidence }
        }
        return canonical
    }

    @inline(never)
    private func recoverPhysical(_ context: PlanarPrescribedRootReactionContext, full: [Double], outputFrame: EntityID,
                                 policy: PlanarPrescribedRootReactionPolicy, loadWork: inout LoadWork,
                                 work: inout NumericalWork) throws(PlanarPrescribedRootReactionError) -> PlanarPrescribedRootReactionReport {
        let source=context.source,snapshot=context.physical.input.snapshot,tree=snapshot.tree,n=source.dynamics.velocityCount
        let pose: RigidTransform
        do throws(JointError) { pose=try snapshot.frame(outputFrame).motion.pose } catch { throw .tree(.joints(error)) }
        guard pose.rotation.x == 0,pose.rotation.y == 0 else { throw .dynamics(.nonplanarInput) }
        let count=snapshot.bodies.count
        var net=[PlanarReactionWrench](repeating:PlanarReactionArithmetic.zero,count:count),parent=[Int](repeating:-1,count:count)
        var inertial=[Double](repeating:0,count:n),generalized=inertial
        for joint in tree.joints {
            try A.check(policy);try A.charge(4,&work)
            let child=try index(tree,joint.childBody),ancestor=try index(tree,joint.parentBody)
            guard child > ancestor,parent[child] == -1 else { throw .invalidSupplierEvidence };parent[child]=ancestor
        }
        for i in 0..<count {
            try A.check(policy);try A.charge(129,&work)
            let body=snapshot.bodies[i],point=body.motion.pose.translation
            let original=try A.tree { () throws(ReactionPathError) in
                try physical.originalBody(context.physical,body:body.body,acceleration:source.motion.motion.values,point:point,policy:policy.tree,work:&work)
            }
            let columns=try columns(snapshot,body.body)
            for (j,column) in columns.enumerated() {
                try A.charge(16,&work);inertial[j]=try A.finite(inertial[j]+A.projection(original,column))
            }
            net[i]=try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.shifted(original,from:point,to:.zero) }
            if let field=context.physical.input.gravity {
                let properties=context.physical.input.inertias[i].properties
                let com=try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.core { () throws(CoreError) in
                    try body.motion.pose.transforming(point:Vector3(properties.centerX,properties.centerY,0))
                } }
                let gravity=try A.tree { () throws(ReactionPathError) in
                    try physical.originalGravity(field,body:body.body,point:com,mass:properties.mass,loadWork:&loadWork)
                }
                net[i]=try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.subtract(net[i],gravity) }
            }
        }
        for load in context.physical.input.bodyWrenches {
            try A.check(policy);try A.charge(256,&work)
            let i=try index(tree,load.body),body=snapshot.bodies[i]
            let value=try A.tree { () throws(ReactionPathError) in
                let original=try physical.originalLoad(load,state:body)
                return try PlanarReactionArithmetic.shifted(original,from:body.motion.pose.translation,to:.zero)
            }
            net[i]=try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.subtract(net[i],value) }
        }
        for i in 0..<count {
            try A.check(policy);try A.charge(64,&work)
            let value=try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.shifted(net[i],from:.zero,to:snapshot.bodies[i].motion.pose.translation) }
            for (j,column) in try columns(snapshot,snapshot.bodies[i].body).enumerated() {
                try A.charge(16,&work);generalized[j]=try A.finite(generalized[j]+A.projection(value,column))
            }
        }
        var maximum=0.0
        for i in 0..<n {
            try A.check(policy);try A.charge(16,&work)
            // Canonical full force, body projection, and retained known load budget must all agree.
            _=try A.residual(inertial[i],full[i],index:i,policy:policy.tree)
            let known=try A.finite(inertial[i]-generalized[i])
            let assembledKnown: Double
            do throws(DynamicsError) { assembledKnown=try source.dynamics.forces.total(at:i) } catch { throw .dynamics(error) }
            _=try A.residual(known,assembledKnown,index:i,policy:policy.tree)
            if i < context.rootEffort.count {
                do throws(PlanarPrescribedRootReactionError) { maximum=max(maximum,try A.residual(generalized[i],context.reaction[i],index:i,policy:policy.tree)) }
                catch { throw .originalRootEffort(index:i) }
            } else { maximum=max(maximum,try A.residual(generalized[i],0,index:i,policy:policy.tree)) }
            maximum=max(maximum,try A.residual(full[i],try A.finite(known+context.reaction[i]),index:i,policy:policy.tree))
        }
        return try publish(context,net:net,parent:parent,pose:pose,outputFrame:outputFrame,maximum:maximum,
            policy:policy,loadWork:loadWork,work:&work)
    }

    @inline(never)
    private func publish(_ context: PlanarPrescribedRootReactionContext, net: [PlanarReactionWrench], parent: [Int],
                         pose: RigidTransform, outputFrame: EntityID, maximum: Double,
                         policy: PlanarPrescribedRootReactionPolicy, loadWork: LoadWork,
                         work: inout NumericalWork) throws(PlanarPrescribedRootReactionError) -> PlanarPrescribedRootReactionReport {
        let snapshot=context.physical.input.snapshot,tree=snapshot.tree,count=net.count
        var subtree=net
        if count > 1 {
            for i in stride(from:count-1,through:1,by:-1) {
                try A.check(policy);try A.charge(12,&work)
                guard parent[i] >= 0 else { throw .invalidSupplierEvidence }
                subtree[parent[i]]=try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.add(subtree[parent[i]],subtree[i]) }
            }
        }
        var balance=subtree
        for i in 1..<count {
            try A.check(policy);try A.charge(12,&work)
            balance[parent[i]]=try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.subtract(balance[parent[i]],subtree[i]) }
        }
        for i in 0..<count {
            try A.check(policy);try A.charge(24,&work)
            guard try A.tree({ () throws(ReactionPathError) in try PlanarReactionArithmetic.agrees(balance[i],net[i],policy:policy.tree) }) else { throw .tree(.originalBodyBalance(body:snapshot.bodies[i].body)) }
        }
        let point=snapshot.bodies[0].motion.pose.translation
        let root=try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.shifted(subtree[0],from:.zero,to:point) }
        var rootMaximum=0.0
        let rootColumns=try columns(snapshot,snapshot.bodies[0].body)
        for i in context.rootEffort.indices {
            try A.check(policy);try A.charge(32,&work)
            let value=try A.projection(root,rootColumns[rootColumns.startIndex+i])
            do throws(PlanarPrescribedRootReactionError) { rootMaximum=max(rootMaximum,try A.residual(value,context.rootEffort[i],index:i,policy:policy.tree)) }
            catch { throw .originalRootEffort(index:i) }
        }
        var joints:[PlanarJointReactionWrench]=[];joints.reserveCapacity(tree.joints.count)
        for joint in tree.joints {
            try A.check(policy);try A.charge(384,&work)
            let i=try index(tree,joint.childBody),reference: Vector3
            do throws(JointError) { reference=try snapshot.frame(joint.childAnchor.frame).motion.pose.translation } catch { throw .tree(.joints(error)) }
            let value=try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.converted(subtree[i],referenceWorld:reference,pose:pose) }
            let framed=try framePoint(reference,pose)
            joints.append(PlanarJointReactionWrench(joint:joint.id,parentBody:joint.parentBody,childBody:joint.childBody,frame:outputFrame,
                referencePoint:framed,referencePointWorld:reference,parentOnChild:value,childOnParent:PlanarReactionArithmetic.negated(value),timeSeconds:snapshot.time,revision:tree.revision))
        }
        try A.check(policy);try A.charge(384,&work)
        let supportValue=try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.converted(subtree[0],referenceWorld:point,pose:pose) }
        let support=PlanarRootSupportWrench(rootBody:snapshot.bodies[0].body,frame:outputFrame,referencePoint:try framePoint(point,pose),
            referencePointWorld:point,supportOnRoot:supportValue,rootOnSupport:PlanarReactionArithmetic.negated(supportValue),timeSeconds:snapshot.time,revision:tree.revision)
        try A.check(policy)
        return PlanarPrescribedRootReactionReport(source:context.source,joints:joints,support:support,rootActuationEffort:context.rootEffort,
            originalRank:context.rank,maximumScaledOriginalGeneralizedResidual:maximum,maximumScaledRootEffortResidual:rootMaximum,numericalWork:work,loadWork:loadWork)
    }
    private func index(_ tree: KinematicTree, _ body: EntityID) throws(PlanarPrescribedRootReactionError) -> Int {
        do throws(JointError) { return try tree.bodyIndex(body) } catch { throw .tree(.joints(error)) }
    }
    private func columns(_ snapshot: KinematicSnapshot, _ body: EntityID) throws(PlanarPrescribedRootReactionError) -> ArraySlice<SpatialMotion> {
        do throws(JointError) { return try snapshot.geometricColumns(body:body) } catch { throw .tree(.joints(error)) }
    }
    private func framePoint(_ point: Vector3, _ pose: RigidTransform) throws(PlanarPrescribedRootReactionError) -> Vector3 {
        try A.tree { () throws(ReactionPathError) in try PlanarReactionArithmetic.core { () throws(CoreError) in try pose.inverted().transforming(point:point) } }
    }
}

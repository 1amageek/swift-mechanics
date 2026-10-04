public struct PlanarClosedLoopReactionRecovery: PlanarClosedLoopReactionRecovering {
    private let equations: any PhysicalRigidEquationComputing
    public init(equations: any PhysicalRigidEquationComputing = RigidEquationKernel()) { self.equations=equations }

    @inline(never)
    public func recover(_ input: PlanarClosedLoopReactionInput, outputFrame: EntityID, policy: ClosedLoopReactionPolicy,
                        loadWork: inout LoadWork, work: inout NumericalWork) throws(ClosedLoopReactionError) -> PlanarClosedLoopReactionReport {
        try admit(input,policy:policy,work:&work)
        let source=try PlanarLoopOriginalSource(input.dynamics)
        let allocation=try originalAllocation(input,policy:policy,work:&work)
        let rows=allocation.rows,rank=allocation.originalRank
        try validateSource(source.input.snapshot,input:input,rows:rows,policy:policy,work:&work)
        try validateSource(input.motion.motion.sourceSnapshot,input:input,rows:rows,policy:policy,work:&work)
        let declared=input.motion.motion.rank
        guard declared.rank == rank.rank, declared.independentRows == rank.independentRows,
              declared.dependentRowIDs == rank.dependentRowIDs, declared.reactionNullity == rank.reactionNullity else { throw .invalidRankEvidence }
        let residual=try acceptRows(input,rows:rows,policy:policy,work:&work)
        let pose: RigidTransform
        do { pose=try rows.original.snapshot.frame(outputFrame).motion.pose } catch { throw .tree(.joints(error)) }
        guard pose.rotation.x == 0,pose.rotation.y == 0 else { throw .dynamics(.nonplanarInput) }
        let result=try loopLoads(input,rows:rows,outputFrame:outputFrame,pose:pose,policy:policy,work:&work)
        let augmented=try augmentedSystem(input,source:source,loads:result.loads,rows:rows,policy:policy,loadWork:&loadWork,work:&work)
        // Final physical acceptance cannot be overridden by the injected assembly supplier.
        let tree: PlanarTreeReactionReport
        do throws(ReactionPathError) {
            tree=try PlanarTreeReactionRecovery().recover(augmented,acceleration:input.motion.motion.values,topology:.completeTree,
                outputFrame:outputFrame,policy:policy.tree,loadWork:&loadWork,work:&work)
        } catch { throw .tree(error) }
        try ClosedLoopArithmetic.check(policy)
        return PlanarClosedLoopReactionReport(source:input,originalAllocation:allocation,loops:result.reactions,tree:tree,
            maximumOriginalPositionResidual:residual.position,maximumOriginalVelocityResidual:residual.velocity,
            maximumOriginalAccelerationResidual:residual.acceleration,numericalWork:work,loadWork:loadWork)
    }

    @inline(never)
    private func originalAllocation(_ input:PlanarClosedLoopReactionInput,policy:ClosedLoopReactionPolicy,
                                    work:inout NumericalWork) throws(ClosedLoopReactionError)->GeometricPhysicalAllocationWitness {
        let originalRows:GeometricPhysicalRowWitness
        do throws(GeometricConstraintError) {
            let sample=try GeometricRelationEvaluator().evaluate(input.geometry,state:input.state,policy:policy.geometry.evaluation,work:&work)
            originalRows=try GeometricRelationEvaluator().physicalRows(input.geometry,state:input.state,supplied:sample,policy:policy.geometry,work:&work)
        } catch { throw .geometry(error) }
        do throws(GeometricPhysicalAllocationError) {
            let allocationPolicy=try GeometricPhysicalAllocationPolicy(rows:policy.geometry,rank:policy.rank)
            _=try GeometricPhysicalAllocationEvaluator().physicalAllocation(input.geometry,state:input.state,supplied:originalRows,policy:allocationPolicy,work:&work)
            return try GeometricPhysicalAllocationAcceptance.validated(input.allocation,system:input.geometry,state:input.state,policy:allocationPolicy,work:&work)
        } catch {
            switch error {
            case .ambiguousPhysicalRow:
                let originalRank:ConstraintRankEvidence
                do throws(ConstraintError) { originalRank=try WeightedConstraintAssembler().rank(originalRows.original.velocity,policy:policy.rank,work:&work) }
                catch { throw .constraint(error) }
                throw .ambiguousAllocation(nullity:originalRank.reactionNullity)
            case .geometry(let cause): throw .geometry(cause)
            case .constraint(let cause): throw .constraint(cause)
            case .numerical(let cause): throw .numerical(cause)
            case .invalidPolicy: throw .invalidInput
            case .staleSource: throw .staleSource
            case .cancelled: throw .cancelled
            }
        }
    }
    private func reduced(_ wrench:SpatialWrench) throws(ClosedLoopReactionError)->PlanarLoopWrench {
        guard wrench.force.z == 0,wrench.torque.x == 0,wrench.torque.y == 0 else { throw .dynamics(.nonplanarInput) }
        return PlanarLoopWrench(forceX:wrench.force.x,forceY:wrench.force.y,momentZ:wrench.torque.z)
    }

    @inline(never)
    private func admit(_ input: PlanarClosedLoopReactionInput, policy: ClosedLoopReactionPolicy, work: inout NumericalWork) throws(ClosedLoopReactionError) {
        try ClosedLoopArithmetic.check(policy)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Spatial and impulse conversion are outside this additive planar port. Existing spatial recovery remains available; this branch must refuse unsupported temporal/dimension input until independently qualified.
        guard input.dynamics.input.dimension == .planar, input.geometry.model.tree.bodies.allSatisfy({ $0.dimension == .planar }) else { throw .dynamics(.dimensionMismatch) }
        guard input.motion.motion.temporalMeaning == .accelerationForce else { throw .unsupportedTemporalMeaning }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Prescribed support work and unseen mesh/bearing connections are not recovered by this bounded planar loop composition. Successful output requires the declared complete tree/row inventory and autonomous dynamic endpoints.
        guard input.topology == .completeTreeAndDeclaredRows else { throw .unrepresentedConnections }
        guard input.geometry.model.tree.rootBase == .fixed, input.geometry.prescribedMotion == nil, input.state.prescribedAnchors.isEmpty else { throw .unsupportedSupportDomain }
        let n=input.dynamics.velocityCount, m=input.geometry.rowIDs.count, b=input.dynamics.input.snapshot.bodies.count
        guard m <= policy.maximumRows, m <= policy.geometry.evaluation.maximumRows, m <= policy.rank.evaluation.maximumRows,
              n <= policy.geometry.evaluation.maximumCoordinates, n <= policy.rank.evaluation.maximumCoordinates,
              n <= policy.admission.capacity.maximumVelocities, b <= policy.tree.maximumBodies,
              b <= policy.geometry.maximumBodies, b <= policy.admission.capacity.maximumBodies,
              input.dynamics.input.snapshot.tree.joints.count <= policy.tree.maximumJoints else { throw .capacityExceeded }
        let totalLoads=try ClosedLoopArithmetic.numeric { () throws(NumericalError) in
            try NumericalWork.sum(input.dynamics.input.bodyWrenches.count,NumericalWork.product(2,m))
        }
        guard totalLoads <= policy.tree.maximumBodyLoads, totalLoads <= policy.admission.capacity.maximumBodyWrenches else { throw .capacityExceeded }
        guard n > 0, input.originalDrive.count == n, input.motion.motion.values.count == n,
              input.motion.motion.generalizedReaction.count == n, input.motion.motion.rowMultipliers.count == m,
              policy.tree.generalizedForceScales.count == n else { throw .invalidShape }
        guard input.originalDrive.allSatisfy({$0.isFinite}), input.motion.motion.values.allSatisfy({$0.isFinite}),
              input.motion.motion.rowMultipliers.allSatisfy({$0.isFinite}), input.motion.motion.generalizedReaction.allSatisfy({$0.isFinite}) else { throw .invalidInput }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Generalized-only drive/load values do not identify reduced body force/couple allocation. This path succeeds only when all actual known loads have original identified body wrenches.
        guard input.originalDrive.allSatisfy({$0 == 0}), input.dynamics.input.generalizedForces.allSatisfy({$0.values.allSatisfy({$0 == 0})}) else { throw .unallocatableGeneralizedLoad }
        guard input.motion.motion.rowIDs == input.geometry.rowIDs, sameLayout(input.motion.motion.layout,input.geometry.layout),
              input.motion.motion.basis == input.geometry.model.tree.layout,
              input.motion.motion.sourceVelocity == input.state.v, input.dynamics.input.velocity == input.state.v,
              input.motion.motion.time == input.state.time, input.motion.motion.frame == input.geometry.model.tree.worldFrame else { throw .staleSource }
        let storage=try ClosedLoopArithmetic.numeric { () throws(NumericalError) -> Int in
            let width=try NumericalWork.sum(n,1)
            let retained=try NumericalWork.sum(input.geometry.scalarStorage,NumericalWork.product(2,input.dynamics.scalarStorage))
            let bodies=try NumericalWork.product(2048,NumericalWork.product(b,width))
            let rows=try NumericalWork.product(512,NumericalWork.product(m,width))
            return try NumericalWork.sum(retained,NumericalWork.sum(bodies,NumericalWork.sum(rows,NumericalWork.product(64,totalLoads))))
        }
        try ClosedLoopArithmetic.numeric { () throws(NumericalError) in try work.requireStorage(storage) }
        let charge=try ClosedLoopArithmetic.numeric { () throws(NumericalError) in try NumericalWork.product(128,NumericalWork.sum(n,m)) }
        try ClosedLoopArithmetic.charge(charge,&work)
        for relation in input.geometry.relations {
            try ClosedLoopArithmetic.check(policy)
            guard !relation.target.isExplicitTime, relation.kind != .coincidence || relation.target.value == .zero,
                  relation.first.body != relation.second.body else { throw .unsupportedSupportDomain }
            for endpoint in [relation.first,relation.second] {
                guard input.geometry.model.descriptor.bodies.first(where:{$0.id == endpoint.body})?.mode == .dynamic else { throw .unsupportedSupportDomain }
            }
        }
    }
    private func sameLayout(_ a: ConstraintCoordinateLayout, _ b: ConstraintCoordinateLayout) -> Bool {
        a.revision == b.revision && a.coordinateIDs == b.coordinateIDs && a.dimensions == b.dimensions && a.scales == b.scales && a.timeScale == b.timeScale
    }
    @inline(never)
    private func validateSource(_ snapshot: KinematicSnapshot, input: PlanarClosedLoopReactionInput, rows: GeometricPhysicalRowWitness,
                                policy: ClosedLoopReactionPolicy, work: inout NumericalWork) throws(ClosedLoopReactionError) {
        let original=rows.original
        let supplied=HolonomicGeometrySample(source:input.state,snapshot:snapshot,metadata:original.metadata,values:original.values,
            velocity:original.velocity,alignmentResiduals:original.alignmentResiduals)
        do throws(GeometricConstraintError) {
            try GeometricOriginalAcceptance.validate(supplied,system:input.geometry,state:input.state,
                tolerance:policy.geometry.originalComparisonTolerance,policy:policy.geometry.evaluation,work:&work)
        } catch { throw .geometry(error) }
    }
    @inline(never)
    private func acceptRows(_ input: PlanarClosedLoopReactionInput, rows: GeometricPhysicalRowWitness,
                            policy: ClosedLoopReactionPolicy, work: inout NumericalWork) throws(ClosedLoopReactionError) -> (position: Double,velocity: Double,acceleration: Double) {
        let sample=rows.original.velocity,n=input.dynamics.velocityCount,t=sample.layout.timeScale,s=sample.layout.scales
        var position=0.0,velocity=0.0,acceleration=0.0,reaction=[Double](repeating:0,count:n)
        for row in sample.rowIDs.indices {
            try ClosedLoopArithmetic.check(policy)
            var speed=sample.drift[row],bias=sample.accelerationBias[row]
            for i in 0..<n {
                try ClosedLoopArithmetic.charge(16,&work)
                let a=sample.rows[row*n+i]
                speed=try ClosedLoopArithmetic.finite(speed+a*input.state.v[i]*t/s[i])
                bias=try ClosedLoopArithmetic.finite(bias+a*input.motion.motion.values[i]*t*t/s[i])
                reaction[i]=try ClosedLoopArithmetic.finite(reaction[i]+a*input.motion.motion.rowMultipliers[row]/s[i])
            }
            let g=abs(rows.original.values[row])
            guard g <= policy.positionTolerance, abs(speed) <= policy.velocityTolerance,
                  abs(bias) <= policy.accelerationTolerance else { throw .originalGeometry(row:sample.rowIDs[row]) }
            position=max(position,g);velocity=max(velocity,abs(speed));acceleration=max(acceleration,abs(bias))
        }
        for value in rows.original.alignmentResiduals {
            guard max(abs(value.x),max(abs(value.y),abs(value.z))) <= policy.positionTolerance else { throw .originalGeometry(row:0) }
        }
        for i in 0..<n {
            try ClosedLoopArithmetic.check(policy);try ClosedLoopArithmetic.charge(8,&work)
            let scale=policy.tree.generalizedForceScales[i]
            let error=try ClosedLoopArithmetic.finite((reaction[i]-input.motion.motion.generalizedReaction[i])/scale)
            let magnitude=try ClosedLoopArithmetic.finite(max(abs(reaction[i]),abs(input.motion.motion.generalizedReaction[i]))/scale)
            guard try ClosedLoopArithmetic.core({ () throws(CoreError) in try policy.tree.generalizedTolerance.contains(error:error,scale:magnitude) }) else {
                throw .originalGeneralizedReaction(index:i)
            }
        }
        return (position,velocity,acceleration)
    }
    @inline(never)
    private func loopLoads(_ input: PlanarClosedLoopReactionInput, rows: GeometricPhysicalRowWitness, outputFrame: EntityID, pose: RigidTransform,
                           policy: ClosedLoopReactionPolicy, work: inout NumericalWork) throws(ClosedLoopReactionError) -> (loads:[BodyWrenchContribution],reactions:[PlanarLoopRowReaction]) {
        // A new owned inventory is necessary because loop loads extend, rather than overwrite, the immutable original source.
        var loads=input.dynamics.input.bodyWrenches,reactions:[PlanarLoopRowReaction]=[]
        let total=try ClosedLoopArithmetic.numeric { () throws(NumericalError) in try NumericalWork.sum(loads.count,NumericalWork.product(2,rows.rows.count)) }
        loads.reserveCapacity(total);reactions.reserveCapacity(rows.rows.count)
        for (i,row) in rows.rows.enumerated() {
            try ClosedLoopArithmetic.check(policy);try ClosedLoopArithmetic.charge(512,&work)
            let mu=input.motion.motion.rowMultipliers[i]
            let first=try wrench(row.first,mu:mu),second=try wrench(row.second,mu:mu)
            for (endpoint,value) in [(row.first,first),(row.second,second)] {
                do throws(DynamicsError) {
                    loads.append(try BodyWrenchContribution(body:endpoint.body,frame:endpoint.worldFrame,
                        referencePoint:endpoint.referencePointWorld,wrench:value,channel:.constraint))
                } catch { throw .dynamics(error) }
            }
            let common=row.first.referencePointWorld
            let shiftedSecond=try shifted(second,from:row.second.referencePointWorld,to:common)
            let negativeFirst=try ClosedLoopArithmetic.core { () throws(CoreError) in
                SpatialWrench(torque:try first.torque.scaled(by:-1),force:try first.force.scaled(by:-1))
            }
            guard try ClosedLoopArithmetic.agrees(shiftedSecond.force,negativeFirst.force,policy.tree.forceTolerance),
                  try ClosedLoopArithmetic.agrees(shiftedSecond.torque,negativeFirst.torque,policy.tree.torqueTolerance) else { throw .originalActionReaction(row:row.rowID) }
            let pair=try ClosedLoopArithmetic.core { () throws(CoreError) in
                let inverse=pose.rotation.conjugated()
                return (SpatialWrench(torque:try inverse.rotating(first.torque),force:try inverse.rotating(first.force)),
                        SpatialWrench(torque:try inverse.rotating(shiftedSecond.torque),force:try inverse.rotating(shiftedSecond.force)))
            }
            let point=try ClosedLoopArithmetic.core { () throws(CoreError) in try pose.inverted().transforming(point:common) }
            reactions.append(PlanarLoopRowReaction(rowID:row.rowID,kind:row.kind,normalizationScale:row.normalizationScale,isStructuralZero:row.isStructuralZero,multiplierJoules:mu,
                firstBody:row.first.body,secondBody:row.second.body,firstEndpointWorld:row.first.referencePointWorld,secondEndpointWorld:row.second.referencePointWorld,
                frame:outputFrame,referencePoint:point,referencePointWorld:common,secondOnFirst:try reduced(pair.0),firstOnSecond:try reduced(pair.1),
                timeSeconds:input.state.time,revision:input.state.revision))
        }
        return (loads,reactions)
    }
    private func wrench(_ endpoint: GeometricRowEndpointCovector, mu: Double) throws(ClosedLoopReactionError) -> SpatialWrench {
        try ClosedLoopArithmetic.core { () throws(CoreError) in SpatialWrench(torque:try endpoint.angularGradient.scaled(by:mu),force:try endpoint.linearGradient.scaled(by:mu)) }
    }
    private func shifted(_ value: SpatialWrench, from: Vector3, to: Vector3) throws(ClosedLoopReactionError) -> SpatialWrench {
        try ClosedLoopArithmetic.core { () throws(CoreError) in SpatialWrench(torque:try value.torque.adding(from.subtracting(to).cross(value.force)),force:value.force) }
    }
    @inline(never)
    private func augmentedSystem(_ input: PlanarClosedLoopReactionInput, source:PlanarLoopOriginalSource, loads: [BodyWrenchContribution], rows: GeometricPhysicalRowWitness,
                                 policy: ClosedLoopReactionPolicy, loadWork: inout LoadWork, work: inout NumericalWork) throws(ClosedLoopReactionError) -> PhysicalRigidDynamicsSystem {
        let original=source.input, augmented:PhysicalRigidDynamicsInput
        do throws(DynamicsError) { augmented=try PhysicalRigidDynamicsInput(planar:PlanarRigidDynamicsInput(snapshot:original.snapshot,velocity:original.velocity,inertias:original.inertias,
            gravity:original.gravity,bodyWrenches:loads,generalizedForces:original.generalizedForces)) }
        catch { throw .dynamics(error) }
        try ClosedLoopArithmetic.charge(1,&work)
        do { try loadWork.charge(1) } catch { throw .loads(error) }
        let before=work,beforeLoad=loadWork
        var supplierWork=work,supplierLoad=loadWork,value:PhysicalRigidDynamicsSystem?,failure:DynamicsError?
        do throws(DynamicsError) { value=try equations.assemble(augmented,admission:policy.admission,loadWork:&supplierLoad,work:&supplierWork) }
        catch { failure=error }
        var ledgerFailure:ClosedLoopReactionError?
        do throws(ClosedLoopReactionError) { try ClosedLoopArithmetic.validate(before,&supplierWork) } catch { ledgerFailure=error }
        work=supplierWork
        do throws(ClosedLoopReactionError) { try ClosedLoopArithmetic.merge(beforeLoad,supplier:supplierLoad,into:&loadWork) } catch { ledgerFailure=error }
        if let ledgerFailure { throw ledgerFailure }
        if let failure { throw .dynamics(failure) }
        guard let value else { throw .invalidSupplierEvidence }
        try ClosedLoopArithmetic.check(policy)
        let returned=try PlanarLoopOriginalSource(value)
        guard value.input.velocity == augmented.velocity, returned.input.inertias == original.inertias,
              value.input.gravity == augmented.gravity, value.input.bodyWrenches == augmented.bodyWrenches,
              value.input.generalizedForces == augmented.generalizedForces, value.velocityCount == augmented.velocity.count else { throw .invalidSupplierEvidence }
        try validateSource(value.input.snapshot,input:input,rows:rows,policy:policy,work:&work)
        return value
    }
}

/// Shared original rigid assembly, momentum and reaction acceptance for all nonlinear facades.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class NonlinearPhysicalEngine: Sendable {
    let model:CompiledMechanicalModel
    let velocityLayout:ConstraintCoordinateLayout
    let drive:[Double]
    let policy:MechanismSolvePolicy
    let admission:DynamicsAdmission
    let inertias:NonlinearPhysicalInertias
    let suppliers:NonlinearPhysicalSuppliers
    let storage:Int
    convenience init(model:CompiledMechanicalModel,velocityLayout:ConstraintCoordinateLayout,drive:[Double],policy:MechanismSolvePolicy,
         admission:DynamicsAdmission,inertias:[RigidBodyInertia],kernel:any RigidEquationComputing,
         solver:any ConstrainedMechanismSolving,storage:Int) {
        self.init(model:model,velocityLayout:velocityLayout,drive:drive,policy:policy,admission:admission,
            inertias:.spatial(inertias),suppliers:.spatial(kernel,solver),storage:storage)
    }
    init(model:CompiledMechanicalModel,velocityLayout:ConstraintCoordinateLayout,drive:[Double],policy:MechanismSolvePolicy,
         admission:DynamicsAdmission,inertias:NonlinearPhysicalInertias,suppliers:NonlinearPhysicalSuppliers,storage:Int) {
        self.model=model;self.velocityLayout=velocityLayout;self.drive=drive;self.policy=policy;self.admission=admission
        self.inertias=inertias;self.suppliers=suppliers;self.storage=storage
    }
    static func bind(_ model:CompiledMechanicalModel) throws(MechanismError) -> [RigidBodyInertia] {
        var bound:[RigidBodyInertia]=[];bound.reserveCapacity(model.tree.bodies.count)
        for body in model.tree.bodies {
            // FIXME(INCOMPLETE_IMPLEMENTATION): The legacy-only evolution supplier admits spatial inertia. Planar sources require the explicit physical supplier initializer and its original mass/reaction/energy evidence.
            guard let raw=model.descriptor.bodies.first(where:{$0.id == body.id}),case .spatial(let source)=raw,let inertia=source.inertia else { throw .unsupportedChart }
            do throws(DynamicsError) { bound.append(try RigidBodyInertia(body:body.id,frame:body.frame,properties:inertia.properties)) } catch { throw .dynamics(error) }
        }
        return bound
    }
    func reservedSlots() throws(NumericalError) -> Int { storage }
    func snapshot(q:[Double],v:[Double],time:Double,work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) -> KinematicSnapshot {
        if let control { try control.beginWorkBlock(units:1) }
        // Two lower tree evaluations are required by makeState/evaluate. Charge their bounded body/column envelope before either callback.
        do { try work.chargeOperations(try NumericalWork.product(512,try NumericalWork.product(model.tree.bodies.count,try NumericalWork.sum(1,v.count)))) }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Compiled tree callback work admission exhausted.") }
        do { return try model.evaluate(model.makeState(KinematicState(revision:model.stamp.revision,time:time,q:q,v:v,acceleration:[Double](repeating:0,count:v.count)))) }
        catch { throw RuntimeFailure(.invalidState,message:"Actual compiled manifold evaluation failed.") }
    }
    func system(q:[Double],v:[Double],time:Double,work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) -> PhysicalRigidDynamicsSystem {
        let snapshot=try snapshot(q:q,v:v,time:time,work:&work,control:control)
        return try system(snapshot:snapshot,v:v,work:&work,control:control)
    }
    @inline(never)
    func system(snapshot:KinematicSnapshot,v:[Double],work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) -> PhysicalRigidDynamicsSystem {
        let input:PhysicalRigidDynamicsInput
        do throws(DynamicsError) { input=try inertias.input(snapshot:snapshot,velocity:v) }
        catch { throw RuntimeFailure(.invalidState,message:"Rigid dynamics input failed.") }
        var local=try supplier(&work,control:control),load:LoadWork
        do { load=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0)) } catch { throw RuntimeFailure(.invalidInput,message:"Load budget invalid.") }
        let before=local;var result:PhysicalRigidDynamicsSystem?,failure:DynamicsError?
        do throws(DynamicsError) { result=try suppliers.assemble(input,admission:admission,load:&load,work:&local) } catch { failure=error }
        try finish(local,before:before,into:&work)
        guard load.budget.maximumWork == 0,load.budget.maximumScalars == 0,load.consumed == 0,load.peakScalars == 0 else {
            throw RuntimeFailure(.invalidOwnerAccess,message:"Rigid supplier changed zero-load admission.",failedSupplierWorkUnavailable:true)
        }
        if let failure { throw RuntimeFailure(.invalidState,message:"Rigid assembly failed.",failedSupplierWorkUnavailable:MechanismError.dynamics(failure).failedSupplierWorkUnavailable) }
        try sourceComparisonAdmission(&work)
        guard let result,result.massMatrix.count == v.count*v.count,NonlinearPhysicalSource.matches(result.input,input) else { throw RuntimeFailure(.invalidState,message:"Rigid supplier result source differs.") }
        return result
    }
    @inline(never)
    func solve(_ context:NonlinearPhysicalSolveContext,work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) -> ConstrainedMotion {
        let result=try invokePhysicalSupplier(context,work:&work,control:control)
        try acceptPhysicalSupplier(context,result:result,work:&work)
        return result
    }
    @inline(never)
    func invokePhysicalSupplier(_ context:NonlinearPhysicalSolveContext,work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) -> ConstrainedMotion {
        // Reserve an irreversible admission quantum before all opaque callbacks; each independent ledger also has a seed.
        var a:NumericalWork,b:NumericalWork,c:NumericalWork,d:NumericalWork
        if control == nil {
            (a,b,c,d)=try coldSuppliers(&work)
        } else {
            a=try supplier(&work,control:control);b=try supplier(&work,control:control)
            c=try supplier(&work,control:control);d=try supplier(&work,control:control)
        }
        let before=[a,b,c,d];var result:ConstrainedMotion?,failure:MechanismError?
        do throws(MechanismError) {
            if context.impulse { result=try invokeVelocity(context,a:&a,b:&b,c:&c,d:&d) }
            else { result=try invokeAcceleration(context,a:&a,b:&b,c:&c,d:&d) }
        } catch { failure=error }
        for (ledger,prior) in zip([a,b,c,d],before) { try finish(ledger,before:prior,into:&work) }
        if let failure { throw RuntimeFailure(.invalidState,message:"Original constrained physical solve failed.",failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        guard let result else { throw RuntimeFailure(.invalidState,message:"Mechanism supplier source/result differs.") }
        return result
    }
    /// One aggregate cold allowance is partitioned only after every boundary marker is reserved.
    private func coldSuppliers(_ work:inout NumericalWork) throws(RuntimeFailure) -> (NumericalWork,NumericalWork,NumericalWork,NumericalWork) {
        try charge(4,&work)
        do throws(NumericalError) {
            let remaining=try work.remainingBudget(reservedStorage:reservedSlots())
            guard remaining.arithmeticOperations >= 4 else { throw .resourceLimit(resource:.arithmeticOperations,limit:work.budget.arithmeticOperations) }
            func ledger(_ index:Int) throws(NumericalError) -> NumericalWork {
                let operations=remaining.arithmeticOperations/4+(index < remaining.arithmeticOperations%4 ? 1 : 0)
                let iterations=remaining.iterations/4+(index < remaining.iterations%4 ? 1 : 0)
                var result=NumericalWork(budget:try NumericalBudget(scalarStorage:remaining.scalarStorage,arithmeticOperations:operations,iterations:iterations))
                try result.chargeOperations(1);return result
            }
            return (try ledger(0),try ledger(1),try ledger(2),try ledger(3))
        } catch { throw RuntimeFailure(.capacityExceeded,message:"Cold aggregate solver admission exhausted.") }
    }
    @inline(never)
    func invokeVelocity(_ context:NonlinearPhysicalSolveContext,a:inout NumericalWork,b:inout NumericalWork,c:inout NumericalWork,d:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        try suppliers.solve(context,drive:drive,policy:policy,a:&a,b:&b,c:&c,d:&d)
    }
    @inline(never)
    func invokeAcceleration(_ context:NonlinearPhysicalSolveContext,a:inout NumericalWork,b:inout NumericalWork,c:inout NumericalWork,d:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        try suppliers.solve(context,drive:drive,policy:policy,a:&a,b:&b,c:&c,d:&d)
    }
    @inline(never)
    func acceptPhysicalSupplier(_ context:NonlinearPhysicalSolveContext,result:ConstrainedMotion,work:inout NumericalWork) throws(RuntimeFailure) {
        let system=context.system,sample=context.sample,impulse=context.impulse
        try sourceComparisonAdmission(&work)
        guard NonlinearPhysicalSource.matches(result.sourceSnapshot,system.input.snapshot),result.values.count == system.velocityCount,result.values.allSatisfy({$0.isFinite}),result.generalizedReaction.count == system.velocityCount,
              result.rowIDs == sample.rowIDs,result.rowMultipliers.count == sample.rowIDs.count,result.rank.reactionNullity == sample.rowIDs.count-result.rank.rank,
              result.temporalMeaning == (impulse ? .instantaneousVelocityImpulse : .accelerationForce),result.time == system.input.snapshot.time,result.basis == model.tree.layout,result.sourceVelocity == system.input.velocity else { throw RuntimeFailure(.invalidState,message:"Mechanism supplier source/result differs.") }
        // Independent acceptance from original mass and retained tangent rows, including redundant rows.
        let n=system.velocityCount,t=velocityLayout.timeScale,s=velocityLayout.scales,e=policy.dynamics.energyScale
        for row in sample.rowIDs.indices {
            var residual=impulse ? sample.drift[row] : sample.accelerationBias[row]
            for i in 0..<n { try charge(4,&work);residual+=sample.rows[row*n+i]*result.values[i]*(impulse ? t : t*t)/s[i] }
            guard residual.isFinite,abs(residual) <= policy.originalTolerance else { throw RuntimeFailure(.invalidState,message:"Original tangent equation rejects supplier motion.") }
        }
        for i in 0..<n {
            var represented=0.0
            for row in sample.rowIDs.indices { try charge(3,&work);represented+=sample.rows[row*n+i]*result.rowMultipliers[row]/s[i] }
            guard represented.isFinite,abs(represented-result.generalizedReaction[i])*s[i]/(e*(impulse ? t : 1)) <= policy.originalTolerance else { throw RuntimeFailure(.invalidState,message:"Original row transpose rejects reaction representative.") }
            var force=impulse ? 0 : system.inertialBias[i]
            for j in 0..<n { try charge(4,&work);force+=system.massMatrix[i*n+j]*(impulse ? result.values[j]-system.input.velocity[j] : result.values[j]) }
            let applied:Double
            do throws(DynamicsError) { applied=impulse ? result.generalizedReaction[i] : drive[i]+(try system.forces.total(at:i))+result.generalizedReaction[i] }
            catch { throw RuntimeFailure(.invalidState,message:"Original applied force unavailable.") }
            guard force.isFinite,abs(force-applied)*s[i]/(e*(impulse ? t : 1)) <= policy.originalTolerance else { throw RuntimeFailure(.invalidState,message:"Original mass/momentum equation rejects supplier reaction.") }
        }
    }
    @inline(never)
    func energy(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) -> MechanicalEnergy {
        var local=try supplier(&work,control:control),result:MechanicalEnergy?,failure:DynamicsError?
        let before=local
        do throws(DynamicsError) { result=try suppliers.energy(system,acceleration:acceleration,work:&local) }
        catch { failure=error }
        try finish(local,before:before,into:&work)
        if let failure {
            let code:RuntimeFailureCode
            switch failure { case .cancelled:code = .cancelled;case .capacityExceeded:code = .capacityExceeded;default:code = .invalidState }
            throw RuntimeFailure(code,message:"Physical energy supplier failed.",failedSupplierWorkUnavailable:MechanismError.dynamics(failure).failedSupplierWorkUnavailable)
        }
        let original:MechanicalEnergy
        do throws(DynamicsError) { original=try RigidEquationKernel().energy(system,acceleration:acceleration,angularMomentumReference:.zero,requireComplete:false,work:&work) }
        catch { throw RuntimeFailure(.invalidState,message:"Original physical energy failed.") }
        guard let result,result == original else { throw RuntimeFailure(.invalidState,message:"Physical energy source or original evidence differs.") }
        if let control { try control.beginWorkBlock(units:1) }
        guard !policy.isCancelled(),!admission.isCancelled() else { throw RuntimeFailure(.cancelled,message:"Physical energy cancelled.") }
        return original
    }
    func sourceComparisonAdmission(_ work:inout NumericalWork) throws(RuntimeFailure) {
        do {
            let bodyColumns=try NumericalWork.product(model.tree.bodies.count,try NumericalWork.sum(1,model.tree.layout.velocityCount))
            try work.chargeOperations(try NumericalWork.product(512,bodyColumns))
        } catch { throw RuntimeFailure(.capacityExceeded,message:"Physical source comparison work budget exhausted.") }
    }
    func supplier(_ work:inout NumericalWork,control:RuntimeStepControl?) throws(RuntimeFailure) -> NumericalWork {
        if let control { try control.beginWorkBlock(units:1) };try charge(1,&work)
        do { var local=NumericalWork(budget:try work.remainingBudget(reservedStorage:reservedSlots()));try local.chargeOperations(1);return local }
        catch { throw RuntimeFailure(.capacityExceeded,message:"Nonlinear supplier admission exhausted.") }
    }
    func finish(_ local:NumericalWork,before:NumericalWork,into work:inout NumericalWork) throws(RuntimeFailure) {
        guard local.budget == before.budget,local.operations >= before.operations,local.iterations >= before.iterations,local.peakScalarStorage >= before.peakScalarStorage else { throw RuntimeFailure(.invalidOwnerAccess,message:"Nonlinear supplier replaced/reset its admitted ledger.",failedSupplierWorkUnavailable:true) }
        do { try work.absorb(local,reservedStorage:reservedSlots()) } catch { throw RuntimeFailure(.capacityExceeded,message:"Nonlinear aggregate supplier work exhausted.") }
    }
    func charge(_ count:Int,_ work:inout NumericalWork) throws(RuntimeFailure) {
        do { try work.chargeOperations(count) } catch { throw RuntimeFailure(.capacityExceeded,message:"Nonlinear arithmetic budget exhausted.") }
    }
}

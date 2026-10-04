@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension CheckpointedMechanismSleep {
    @inline(never)
    internal func restCertificate(physical:KinematicState,drive:[Double],work:inout NumericalWork) throws(RuntimeFailure) -> MechanismSleepRestCertificate? {
        guard let source=try admitRestSource(physical:physical,drive:drive,work:&work) else { return nil }
        if let retained=memo.read(position:source.physical.q,drive:source.drive) { return retained }
        try sleepNumerical { () throws(NumericalError) in try work.requireStorage(source.reserved) }
        let input=try restInput(source)
        let system=try restAssembly(input,work:&work)
        let rows=try restRows(source,work:&work)
        guard let groups=try restConnectivity(source,system:system,rows:rows,work:&work) else { return nil }
        guard try restEquilibrium(source,system:system,rows:rows,work:&work) else { return nil }
        return try publishRestProof(source,groups:groups)
    }
    @inline(never)
    private func admitRestSource(physical:KinematicState,drive:[Double],work:inout NumericalWork) throws(RuntimeFailure) -> SleepRestSource? {
        try sleepCheck()
        let n=model.tree.layout.velocityCount
        guard physical.revision == model.stamp.revision,physical.q.count == n,physical.v.count == n,drive.count == n,
              physical.time >= constraints.minimumTime,physical.time <= constraints.maximumTime else {
            throw RuntimeFailure(.invalidState,message:"Sleep proof physical/time chart differs.")
        }
        try sleepNumerical { () throws(NumericalError) in try work.requireStorage(try NumericalWork.product(4,n));try work.chargeOperations(try NumericalWork.product(4,n)) }
        guard physical.v.allSatisfy({$0 == 0}) else { return nil }
        let slots=try sleepNumerical { () throws(NumericalError) in
            try NumericalWork.sum(try NumericalWork.product(128,model.tree.bodies.count),try NumericalWork.sum(try NumericalWork.product(8,try NumericalWork.product(n,n)),try NumericalWork.product(32,n)))
        }
        return SleepRestSource(physical:physical,drive:drive,count:n,reserved:slots)
    }
    @inline(never)
    private func restInput(_ source:SleepRestSource) throws(RuntimeFailure) -> SleepRestInput {
        let snapshot=try restSnapshot(source.physical)
        do throws(DynamicsError) { return SleepRestInput(try RigidDynamicsInput(snapshot:snapshot.value,velocity:source.physical.v,inertias:inertias,gravity:nil)) }
        catch { throw RuntimeFailure(.invalidState,message:"Sleep actual tree/inertia state construction failed.") }
    }
    @inline(never)
    private func restSnapshot(_ physical:KinematicState) throws(RuntimeFailure) -> SleepRestSnapshot {
        let state=try restCompiledState(physical)
        do throws(CompilationFailure) { return SleepRestSnapshot(try model.evaluate(state)) }
        catch { throw RuntimeFailure(.invalidState,message:"Sleep actual compiled tree evaluation failed.") }
    }
    @inline(never)
    private func restCompiledState(_ physical:KinematicState) throws(RuntimeFailure) -> CompiledKinematicState {
        do throws(CompilationFailure) { return try model.makeState(physical) }
        catch { throw RuntimeFailure(.invalidState,message:"Sleep actual compiled state admission failed.") }
    }
    @inline(never)
    private func restAssembly(_ input:SleepRestInput,work:inout NumericalWork) throws(RuntimeFailure) -> SleepRestSystem {
        var load:LoadWork
        do { load=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0)) }
        catch { throw RuntimeFailure(.invalidInput,message:"Sleep zero external-load capacity failed.") }
        let before=work
        var output:SleepRestSystem?,failure:DynamicsError?
        do throws(DynamicsError) { output=SleepRestSystem(try RigidEquationKernel().assemble(input.value,admission:admission,loadWork:&load,work:&work)) }
        catch { failure=error }
        try sleepLedger(before,work)
        if let failure { throw RuntimeFailure(.invalidState,message:"Sleep actual rigid mass assembly failed.",failedSupplierWorkUnavailable:MechanismError.dynamics(failure).failedSupplierWorkUnavailable) }
        guard let output else { throw RuntimeFailure(.invalidState,message:"Sleep rigid mass assembly has no result.") };return output
    }
    @inline(never)
    private func restRows(_ source:SleepRestSource,work:inout NumericalWork) throws(RuntimeFailure) -> SleepRestRows {
        let before=work
        var evaluation:ConstraintEvaluation?,failure:ConstraintError?
        do throws(ConstraintError) { evaluation=try QuadraticConstraintEvaluator().evaluate(constraints,position:source.physical.q,velocity:source.physical.v,
            time:source.physical.time,policy:solvePolicy.constraints.evaluation,work:&work) } catch { failure=error }
        try sleepLedger(before,work)
        if let failure { throw RuntimeFailure(.invalidState,message:"Sleep original stationary row evaluation failed.",failedSupplierWorkUnavailable:MechanismError.constraint(failure).failedSupplierWorkUnavailable) }
        guard let evaluation else { throw RuntimeFailure(.invalidState,message:"Sleep row evaluation has no result.") }
        guard evaluation.values.allSatisfy({$0.isFinite && abs($0) <= solvePolicy.originalTolerance}),
              evaluation.timeDerivative.allSatisfy({$0 == 0}),evaluation.accelerationBias.allSatisfy({$0 == 0}) else {
            throw RuntimeFailure(.invalidState,message:"Sleep original stationary position/time rows failed.")
        }
        return SleepRestRows(VelocityConstraintSample(layout:constraints.layout,holonomic:evaluation))
    }
    @inline(never)
    private func restConnectivity(_ source:SleepRestSource,system:SleepRestSystem,rows:SleepRestRows,work:inout NumericalWork) throws(RuntimeFailure) -> [[UInt64]]? {
        try positiveMass(system.value.massMatrix,count:source.count,work:&work)
        let decision:MechanismSleepDecision
        do throws(MechanismError) { decision=try ConnectedMechanismSleep().evaluate(system.value,sample:rows.value,wakeCoordinateIDs:[],policy:policy.thresholds,work:&work) }
        catch { throw RuntimeFailure(.invalidState,message:"Actual connected energy/velocity sleep criterion failed.",failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
        guard decision.asleep.allSatisfy({$0}) else { return nil };return decision.groups
    }
    @inline(never)
    private func restEquilibrium(_ source:SleepRestSource,system:SleepRestSystem,rows:SleepRestRows,work:inout NumericalWork) throws(RuntimeFailure) -> Bool {
        let motion=try solveRestEquilibrium(source,system:system,rows:rows,work:&work)
        return try associateRestEquilibrium(motion,source:source)
    }
    @inline(never)
    private func solveRestEquilibrium(_ source:SleepRestSource,system:SleepRestSystem,rows:SleepRestRows,work:inout NumericalWork) throws(RuntimeFailure) -> ConstrainedMotion {
        let supplierBudget=try sleepNumerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:source.reserved) }
        var outer=NumericalWork(budget:supplierBudget),dynamics=NumericalWork(budget:supplierBudget),rank=NumericalWork(budget:supplierBudget),linear=NumericalWork(budget:supplierBudget)
        for index in 0..<4 {
            switch index {
            case 0:try sleepNumerical { () throws(NumericalError) in try outer.chargeOperations(1) }
            case 1:try sleepNumerical { () throws(NumericalError) in try dynamics.chargeOperations(1) }
            case 2:try sleepNumerical { () throws(NumericalError) in try rank.chargeOperations(1) }
            default:try sleepNumerical { () throws(NumericalError) in try linear.chargeOperations(1) }
            }
        }
        let before=[outer,dynamics,rank,linear]
        var motion:ConstrainedMotion?,failure:MechanismError?
        do throws(MechanismError) { motion=try MassWeightedMechanismSolver().acceleration(system.value,sample:rows.value,drive:source.drive,policy:solvePolicy,
            work:&outer,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear) } catch { failure=error }
        for (prior,ledger) in zip(before,[outer,dynamics,rank,linear]) {
            try sleepLedger(prior,ledger)
            try sleepNumerical { () throws(NumericalError) in try work.absorb(ledger,reservedStorage:source.reserved) }
        }
        if let failure { throw RuntimeFailure(.invalidState,message:"Sleep original constrained equilibrium solve failed.",failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        guard let motion else { throw RuntimeFailure(.invalidState,message:"Sleep force proof has no result.") };return motion
    }
    @inline(never)
    private func associateRestEquilibrium(_ motion:ConstrainedMotion,source:SleepRestSource) throws(RuntimeFailure) -> Bool {
        guard motion.temporalMeaning == .accelerationForce,motion.time == source.physical.time,
              motion.sourceVelocity == source.physical.v,motion.values.count == source.count,motion.basis == model.tree.layout else { throw RuntimeFailure(.invalidState,message:"Sleep force proof source/temporal meaning differs.") }
        return motion.values.allSatisfy({$0 == 0})
    }
    @inline(never)
    private func publishRestProof(_ source:SleepRestSource,groups:[[UInt64]]) throws(RuntimeFailure) -> MechanismSleepRestCertificate {
        var indices:[[Int]]=[]
        for group in groups {
            var coordinates:[Int]=[]
            for id in group {
                guard let index=constraints.layout.coordinateIDs.firstIndex(of:id) else { throw RuntimeFailure(.invalidState,message:"Sleep actual group has unknown coordinate.") };coordinates.append(index)
            };indices.append(coordinates)
        }
        try sleepCheck()
        let certificate=MechanismSleepRestCertificate(position:source.physical.q,drive:source.drive,groups:indices)
        memo.store(certificate);return certificate
    }
    @inline(never)
    private func positiveMass(_ mass:[Double],count:Int,work:inout NumericalWork) throws(RuntimeFailure) {
        let square=try sleepNumerical { () throws(NumericalError) in try NumericalWork.product(count,count) }
        guard mass.count == square else { throw RuntimeFailure(.invalidState,message:"Actual sleep mass matrix shape differs.") }
        var factor=[Double](repeating:0,count:square)
        for i in 0..<count {
            try sleepCheck()
            for j in 0...i {
                try sleepNumerical { () throws(NumericalError) in try work.chargeOperations(3) }
                guard mass[i*count+j].isFinite,mass[i*count+j] == mass[j*count+i] else { throw RuntimeFailure(.invalidState,message:"Sleep mass must be finite symmetric positive definite.") }
                var value=mass[i*count+j]
                for k in 0..<j { try sleepNumerical { () throws(NumericalError) in try work.chargeOperations(2) };value-=factor[i*count+k]*factor[j*count+k] }
                guard value.isFinite else { throw RuntimeFailure(.invalidState,message:"Sleep Cholesky arithmetic is nonfinite.") }
                if i == j {
                    guard value > 0 else { throw RuntimeFailure(.invalidState,message:"Sleep kinetic metric is not positive definite.") };factor[i*count+j]=value.squareRoot()
                } else { factor[i*count+j]=value/factor[j*count+j] }
            }
        }
    }
    internal func sleepCheck() throws(RuntimeFailure) {
        guard !Task.isCancelled,!policy.thresholds.isCancelled(),!solvePolicy.isCancelled() else { throw RuntimeFailure(.cancelled,message:"Mechanism sleep operation cancelled.") }
    }
    internal func sleepLedger(_ before:NumericalWork,_ after:NumericalWork) throws(RuntimeFailure) {
        guard before.budget == after.budget && after.operations >= before.operations && after.iterations >= before.iterations && after.peakScalarStorage >= before.peakScalarStorage else { throw RuntimeFailure(.invalidOwnerAccess,message:"Sleep supplier replaced/reset admitted work ledger.",failedSupplierWorkUnavailable:true) }
    }
    internal func sleepNumerical<T>(_ operation:() throws(NumericalError) -> T) throws(RuntimeFailure) -> T {
        do throws(NumericalError) { return try operation() } catch { throw RuntimeFailure(.capacityExceeded,message:"Sleep work/storage/overflow capacity exhausted.") }
    }
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension AffineMechanismEquation {
    @inline(never)
    internal func stationaryMotion(physical:KinematicState,catalog:StationaryLoadCatalog,selection:StationaryLoadSelection,execution:any StationaryLoadExecuting,work:inout NumericalWork,driveOverride:[Double]? = nil) throws(RuntimeFailure) -> StationaryAffineMotion {
        let source=try stationarySource(physical:physical,catalog:catalog,selection:selection,execution:execution,drive:driveOverride ?? drive,work:&work)
        return try stationaryMotion(source,work:&work)
    }
    @inline(never)
    private func stationaryMotion(_ source:StationaryMotionSource,work:inout NumericalWork) throws(RuntimeFailure) -> StationaryAffineMotion {
        let rows=try stationaryRows(source,work:&work)
        let system=try stationaryAssembly(source,work:&work)
        let motion=try stationarySolve(source,system:system,rows:rows,work:&work)
        return try stationaryAssociation(source,system:system,rows:rows,motion:motion)
    }
    @inline(never)
    private func stationarySource(physical:KinematicState,catalog:StationaryLoadCatalog,selection:StationaryLoadSelection,execution:any StationaryLoadExecuting,drive:[Double],work:inout NumericalWork) throws(RuntimeFailure) -> StationaryMotionSource {
        do throws(StationaryLoadError) { try catalog.validate(model:model,layout:constraints.layout) } catch { throw error.runtimeFailure }
        guard physical.revision == model.stamp.revision,physical.q.count == model.tree.layout.positionCount,physical.v.count == model.tree.layout.velocityCount else { throw RuntimeFailure(.invalidState,message:"Loaded physical source differs.") }
        guard drive.count == physical.v.count,drive.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidInput,message:"Loaded constant drive shape/value differs.") }
        guard !Task.isCancelled,!policy.isCancelled(),!admission.isCancelled() else { throw RuntimeFailure(.cancelled,message:"Loaded physical motion cancelled before source allocation.") }
        _=try reserve(work:&work)
        return StationaryMotionSource(physical:physical,catalog:catalog,selection:selection,execution:execution,drive:drive)
    }
    @inline(never)
    private func stationaryRows(_ source:StationaryMotionSource,work:inout NumericalWork) throws(RuntimeFailure) -> AffineMotionRows {
        AffineMotionRows(try checkedSample(time:source.physical.value.time,point:source.physical.value.q+source.physical.value.v,work:&work,control:nil))
    }
    @inline(never)
    private func stationarySolve(_ source:StationaryMotionSource,system:AffineMotionSystem,rows:AffineMotionRows,work:inout NumericalWork) throws(RuntimeFailure) -> StationaryMotionResult {
        StationaryMotionResult(try motionSolve(system,rows:rows,work:&work,partitionWork:true,driveOverride:source.drive))
    }
    @inline(never)
    private func stationaryAssociation(_ source:StationaryMotionSource,system:AffineMotionSystem,rows:AffineMotionRows,motion:StationaryMotionResult) throws(RuntimeFailure) -> StationaryAffineMotion {
        guard motion.value.temporalMeaning == .accelerationForce,motion.value.time == source.physical.value.time,motion.value.sourceVelocity == source.physical.value.v,
              motion.value.basis == model.tree.layout,motion.value.sourceSnapshot.bodies == system.value.input.snapshot.bodies,
              motion.value.values.count == source.physical.value.v.count,motion.value.values.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Loaded constrained motion source/meaning differs.") }
        return StationaryAffineMotion(system:system.value,rows:rows.value,motion:motion.value)
    }
    @inline(never)
    private func stationaryAssembly(_ source:StationaryMotionSource,work:inout NumericalWork) throws(RuntimeFailure) -> AffineMotionSystem {
        let invocation=try stationaryBeginAssembly(source,work:&work)
        let outcome=stationaryInvokeAssembly(source,invocation:invocation)
        return try stationaryFinishAssembly(source,invocation:invocation,outcome:outcome,work:&work)
    }
    @inline(never)
    private func stationaryBeginAssembly(_ source:StationaryMotionSource,work:inout NumericalWork) throws(RuntimeFailure) -> StationaryAssemblyInvocation {
        let reserved=try reserve(work:&work)
        let numerical=try localWork(work,reserved:reserved)
        let invocation:StationaryLoadInvocation
        do throws(StationaryLoadError) { invocation=try source.execution.beginInvocation() } catch { throw error.runtimeFailure }
        return StationaryAssemblyInvocation(reserved:reserved,numerical:numerical,load:invocation)
    }
    @inline(never)
    private func stationaryInvokeAssembly(_ source:StationaryMotionSource,invocation:StationaryAssemblyInvocation) -> StationaryAssemblyOutcome {
        var load=invocation.load.initialWork,numerical=invocation.numerical
        do throws(RuntimeFailure) {
            let output=try stationaryInputAssembly(source,reserved:invocation.reserved,load:&load,work:&numerical)
            return StationaryAssemblyOutcome(output:output,numerical:numerical,load:load)
        } catch { return StationaryAssemblyOutcome(failure:error,numerical:numerical,load:load) }
    }
    @inline(never)
    private func stationaryFinishAssembly(_ source:StationaryMotionSource,invocation:StationaryAssemblyInvocation,outcome:StationaryAssemblyOutcome,work:inout NumericalWork) throws(RuntimeFailure) -> AffineMotionSystem {
        var finalization:RuntimeFailure?
        do throws(StationaryLoadError) { try source.execution.finishInvocation(invocation.load,work:outcome.load,failedSupplierWorkUnavailable:outcome.failure?.failedSupplierWorkUnavailable ?? false) }
        catch { finalization=error.runtimeFailure }
        try validLocal(outcome.numerical,budget:invocation.numerical.budget);try absorb(outcome.numerical,into:&work,reserved:invocation.reserved)
        if let finalization { throw finalization };if let failure=outcome.failure { throw failure }
        guard let output=outcome.output else { throw RuntimeFailure(.invalidState,message:"Loaded assembly has no output.") };return output
    }
    @inline(never)
    private func stationaryInputAssembly(_ source:StationaryMotionSource,reserved:Int,load:inout LoadWork,work:inout NumericalWork) throws(RuntimeFailure) -> AffineMotionSystem {
        let sample=try stationarySample(source,load:&load)
        let snapshot=try motionSnapshot(source.physical)
        let input=try stationaryInput(source,sample:sample,snapshot:snapshot)
        return try stationaryRigidAssembly(input,reserved:reserved,load:&load,work:&work)
    }
    @inline(never)
    private func stationarySample(_ source:StationaryMotionSource,load:inout LoadWork) throws(RuntimeFailure) -> StationaryMotionSample {
        do throws(StationaryLoadError) { return StationaryMotionSample(try ReferenceStationaryLoadEvaluator().evaluate(source.catalog.program(source.selection),catalog:source.catalog,physical:source.physical.value,work:&load)) }
        catch { throw error.runtimeFailure }
    }
    @inline(never)
    private func stationaryInput(_ source:StationaryMotionSource,sample:StationaryMotionSample,snapshot:AffineMotionSnapshot) throws(RuntimeFailure) -> AffineMotionInput {
        do throws(DynamicsError) { return AffineMotionInput(try RigidDynamicsInput(snapshot:snapshot.value,velocity:source.physical.value.v,inertias:inertias,gravity:sample.value.gravity,generalizedForces:[sample.value.contribution])) }
        catch { throw stationaryDynamicsFailure(error) }
    }
    @inline(never)
    private func stationaryRigidAssembly(_ input:AffineMotionInput,reserved:Int,load:inout LoadWork,work:inout NumericalWork) throws(RuntimeFailure) -> AffineMotionSystem {
        do throws(DynamicsError) { return AffineMotionSystem(try kernel.assemble(input.value,admission:admission,loadWork:&load,work:&work),reserved:reserved) }
        catch { throw stationaryDynamicsFailure(error) }
    }
    private func stationaryDynamicsFailure(_ error:DynamicsError) -> RuntimeFailure {
        let code:RuntimeFailureCode
        switch error { case .cancelled,.loads(.cancelled),.numerical(.cancelled,_):code = .cancelled;default:code = .invalidState }
        return RuntimeFailure(code,message:"Actual gravity/passive rigid assembly failed.",failedSupplierWorkUnavailable:MechanismError.dynamics(error).failedSupplierWorkUnavailable)
    }
}

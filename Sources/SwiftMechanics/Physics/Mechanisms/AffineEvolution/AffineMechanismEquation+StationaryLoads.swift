@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension AffineMechanismEquation {
    @inline(never)
    internal func stationaryMotion(physical:KinematicState,catalog:StationaryLoadCatalog,selection:StationaryLoadSelection,execution:any StationaryLoadExecuting,work:inout NumericalWork,driveOverride:[Double]? = nil) throws(RuntimeFailure) -> StationaryAffineMotion {
        do throws(StationaryLoadError) { try catalog.validate(model:model,layout:constraints.layout) } catch { throw error.runtimeFailure }
        guard physical.revision == model.stamp.revision,physical.q.count == model.tree.layout.positionCount,physical.v.count == model.tree.layout.velocityCount else { throw RuntimeFailure(.invalidState,message:"Loaded physical source differs.") }
        let actualDrive=driveOverride ?? drive
        guard actualDrive.count == physical.v.count,actualDrive.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidInput,message:"Loaded constant drive shape/value differs.") }
        guard !Task.isCancelled,!policy.isCancelled(),!admission.isCancelled() else { throw RuntimeFailure(.cancelled,message:"Loaded physical motion cancelled before source allocation.") }
        _=try reserve(work:&work)
        let rows=AffineMotionRows(try checkedSample(time:physical.time,point:physical.q+physical.v,work:&work,control:nil))
        let system=try stationaryAssembly(physical:physical,catalog:catalog,selection:selection,execution:execution,work:&work)
        let motion=try motionSolve(system,rows:rows,work:&work,partitionWork:true,driveOverride:actualDrive)
        guard motion.temporalMeaning == .accelerationForce,motion.time == physical.time,motion.sourceVelocity == physical.v,
              motion.basis == model.tree.layout,motion.sourceSnapshot.bodies == system.value.input.snapshot.bodies,
              motion.values.count == physical.v.count,motion.values.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Loaded constrained motion source/meaning differs.") }
        return StationaryAffineMotion(system:system.value,rows:rows.value,motion:motion)
    }
    @inline(never)
    private func stationaryAssembly(physical:KinematicState,catalog:StationaryLoadCatalog,selection:StationaryLoadSelection,execution:any StationaryLoadExecuting,work:inout NumericalWork) throws(RuntimeFailure) -> AffineMotionSystem {
        let reserved=try reserve(work:&work)
        var numerical=try localWork(work,reserved:reserved)
        let before=numerical.budget
        let invocation:StationaryLoadInvocation
        do throws(StationaryLoadError) { invocation=try execution.beginInvocation() } catch { throw error.runtimeFailure }
        var load=invocation.initialWork,output:AffineMotionSystem?,failure:RuntimeFailure?
        do throws(RuntimeFailure) { output=try stationaryInputAssembly(physical:physical,catalog:catalog,selection:selection,reserved:reserved,load:&load,work:&numerical) }
        catch { failure=error }
        var finalization:RuntimeFailure?
        do throws(StationaryLoadError) { try execution.finishInvocation(invocation,work:load,failedSupplierWorkUnavailable:failure?.failedSupplierWorkUnavailable ?? false) }
        catch { finalization=error.runtimeFailure }
        try validLocal(numerical,budget:before);try absorb(numerical,into:&work,reserved:reserved)
        if let finalization { throw finalization };if let failure { throw failure }
        guard let output else { throw RuntimeFailure(.invalidState,message:"Loaded assembly has no output.") };return output
    }
    @inline(never)
    private func stationaryInputAssembly(physical:KinematicState,catalog:StationaryLoadCatalog,selection:StationaryLoadSelection,reserved:Int,load:inout LoadWork,work:inout NumericalWork) throws(RuntimeFailure) -> AffineMotionSystem {
        let sample:StationaryLoadSample
        do throws(StationaryLoadError) { sample=try ReferenceStationaryLoadEvaluator().evaluate(catalog.program(selection),catalog:catalog,physical:physical,work:&load) }
        catch { throw error.runtimeFailure }
        let snapshot=try motionSnapshot(AffineMotionPhysical(physical))
        do throws(DynamicsError) {
            let input=try RigidDynamicsInput(snapshot:snapshot.value,velocity:physical.v,inertias:inertias,gravity:sample.gravity,generalizedForces:[sample.contribution])
            return AffineMotionSystem(try kernel.assemble(input,admission:admission,loadWork:&load,work:&work),reserved:reserved)
        } catch {
            let code:RuntimeFailureCode
            switch error { case .cancelled,.loads(.cancelled),.numerical(.cancelled,_):code = .cancelled;default:code = .invalidState }
            throw RuntimeFailure(code,message:"Actual gravity/passive rigid assembly failed.",failedSupplierWorkUnavailable:MechanismError.dynamics(error).failedSupplierWorkUnavailable)
        }
    }
}

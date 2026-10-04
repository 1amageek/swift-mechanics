@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension LoadedCheckpointedMechanismSleep {
    @inline(never)
    internal func loadedImpactVelocity(expected:RuntimeAcceptedState,impulse:MechanismSleepImpulse,work:inout NumericalWork) throws(RuntimeFailure) -> [Double] {
        let physical=expected.checkpoint.physical,n=physical.v.count
        guard impulse.model == model.stamp,impulse.time == physical.time,impulse.acceptedSequence == expected.checkpoint.acceptedSteps,
              impulse.layout.coordinateIDs == constraints.layout.coordinateIDs,impulse.layout.dimensions == constraints.layout.dimensions,
              impulse.layout.scales == constraints.layout.scales,impulse.layout.timeScale == constraints.layout.timeScale,impulse.layout.revision == constraints.layout.revision else { throw RuntimeFailure(.invalidOwnerAccess,message:"Loaded instantaneous impulse source/layout/time/sequence differs.") }
        let reserved=try numerical { () throws(NumericalError) in try NumericalWork.sum(try NumericalWork.product(128,model.tree.bodies.count),try NumericalWork.sum(try NumericalWork.product(8,try NumericalWork.product(n,n)),try NumericalWork.product(32,n))) }
        try numerical { () throws(NumericalError) in try work.requireStorage(reserved) }
        let original=try impactMass(physical,work:&work)
        let free=try loadedFreeVelocity(original,physical:physical,impulse:impulse,work:&work)
        let incoming:KinematicState
        do { incoming=try KinematicState(revision:model.stamp.revision,time:physical.time,q:physical.q,v:free,acceleration:[Double](repeating:0,count:n)) }
        catch { throw RuntimeFailure(.invalidState,message:"Loaded free impulse state failed.") }
        let incomingSystem=try impactMass(incoming,work:&work)
        let result=try loadedReconcile(incomingSystem,reserved:reserved,work:&work)
        guard result.temporalMeaning == .instantaneousVelocityImpulse,result.values.count == n,result.generalizedReaction.count == n,
              result.sourceVelocity == free,result.sourceSnapshot.bodies == incomingSystem.input.snapshot.bodies,result.time == physical.time,result.basis == model.tree.layout else { throw RuntimeFailure(.invalidState,message:"Loaded instantaneous motion original source/meaning differs.") }
        for i in 0..<n {
            var momentum=0.0
            for j in 0..<n { try numerical { () throws(NumericalError) in try work.chargeOperations(3) };momentum+=original.massMatrix[i*n+j]*(result.values[j]-physical.v[j]) }
            let residual=abs(momentum-impulse.values[i]-result.generalizedReaction[i])*constraints.layout.scales[i]/(solvePolicy.dynamics.energyScale*constraints.layout.timeScale)
            guard residual.isFinite,residual <= solvePolicy.originalTolerance else { throw RuntimeFailure(.invalidState,message:"Loaded original M delta-v fails applied plus constraint impulse balance.") }
        }
        return result.values
    }
    @inline(never)
    private func impactMass(_ physical:KinematicState,work:inout NumericalWork) throws(RuntimeFailure) -> RigidDynamicsSystem {
        let snapshot:KinematicSnapshot
        do { snapshot=try model.evaluate(model.makeState(physical)) }
        catch { throw RuntimeFailure(.invalidState,message:"Loaded impact actual compiled source failed.") }
        var inertias:[RigidBodyInertia]=[]
        for body in model.tree.bodies {
            guard let record=model.descriptor.bodies.first(where:{$0.id == body.id}),case .spatial(let source)=record,let representation=source.inertia else { throw RuntimeFailure(.invalidState,message:"Loaded impact source inertia is missing.") }
            do throws(DynamicsError) { inertias.append(try RigidBodyInertia(body:body.id,frame:body.frame,properties:representation.properties)) }
            catch { throw RuntimeFailure(.invalidState,message:"Loaded impact actual inertia binding failed.") }
        }
        try numerical { () throws(NumericalError) in try work.chargeOperations(1) }
        let before=work
        var load:LoadWork
        do { load=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0)) }
        catch { throw RuntimeFailure(.invalidInput,message:"Loaded impulse mass-only load budget failed.") }
        var output:RigidDynamicsSystem?,failure:DynamicsError?
        do throws(DynamicsError) { output=try RigidEquationKernel().assemble(RigidDynamicsInput(snapshot:snapshot,velocity:physical.v,inertias:inertias,gravity:nil),admission:admission,loadWork:&load,work:&work) }
        catch { failure=error }
        try ledger(before,work)
        if let failure { throw RuntimeFailure(.invalidState,message:"Loaded actual impulse mass assembly failed.",failedSupplierWorkUnavailable:MechanismError.dynamics(failure).failedSupplierWorkUnavailable) }
        guard let output else { throw RuntimeFailure(.invalidState,message:"Loaded impulse mass has no result.") };return output
    }
    @inline(never)
    private func loadedFreeVelocity(_ original:RigidDynamicsSystem,physical:KinematicState,impulse:MechanismSleepImpulse,work:inout NumericalWork) throws(RuntimeFailure) -> [Double] {
        try numerical { () throws(NumericalError) in try work.chargeOperations(1) };let before=work
        var output:DynamicsSolution?,failure:DynamicsError?
        do throws(DynamicsError) { output=try DenseRigidDynamics().inverseMassProduct(original,rightHandSide:impulse.values,policy:solvePolicy.dynamics,work:&work) }
        catch { failure=error }
        try ledger(before,work)
        if let failure { throw RuntimeFailure(.invalidState,message:"Loaded original impulse inverse mass failed.",failedSupplierWorkUnavailable:MechanismError.dynamics(failure).failedSupplierWorkUnavailable) }
        guard let output,output.acceleration.count == physical.v.count else { throw RuntimeFailure(.invalidState,message:"Loaded impulse inverse mass shape differs.") }
        var free=physical.v
        for i in free.indices { try numerical { () throws(NumericalError) in try work.chargeOperations(1) };free[i]+=output.acceleration[i];guard free[i].isFinite else { throw RuntimeFailure(.invalidState,message:"Loaded impulse free velocity is nonfinite.") } };return free
    }
    @inline(never)
    private func loadedReconcile(_ incoming:RigidDynamicsSystem,reserved:Int,work:inout NumericalWork) throws(RuntimeFailure) -> ConstrainedMotion {
        let rows=VelocityConstraintSample(layout:constraints.layout,rowIDs:constraints.rows.map({$0.id}),rows:constraints.rows.flatMap({$0.linear}),drift:[Double](repeating:0,count:constraints.rows.count),accelerationBias:[Double](repeating:0,count:constraints.rows.count),isIntegrable:true)
        let budget=try numerical { () throws(NumericalError) in
            let remaining=try work.remainingBudget(reservedStorage:reserved)
            return try NumericalBudget(scalarStorage:remaining.scalarStorage,arithmeticOperations:remaining.arithmeticOperations/4,iterations:remaining.iterations/4)
        }
        var outer=NumericalWork(budget:budget),dynamics=NumericalWork(budget:budget),rank=NumericalWork(budget:budget),linear=NumericalWork(budget:budget)
        try numerical { () throws(NumericalError) in try outer.chargeOperations(1);try dynamics.chargeOperations(1);try rank.chargeOperations(1);try linear.chargeOperations(1) }
        let before=[outer,dynamics,rank,linear]
        var output:ConstrainedMotion?,failure:MechanismError?
        do throws(MechanismError) { output=try MassWeightedMechanismSolver().reconcileVelocity(incoming,sample:rows,policy:solvePolicy,work:&outer,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear) }
        catch { failure=error }
        for (prior,after) in zip(before,[outer,dynamics,rank,linear]) { try ledger(prior,after);try numerical { () throws(NumericalError) in try work.absorb(after,reservedStorage:reserved) } }
        if let failure { throw RuntimeFailure(.invalidState,message:"Loaded actual impulse reconciliation failed.",failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        guard let output else { throw RuntimeFailure(.invalidState,message:"Loaded impulse reconciliation has no output.") };return output
    }
    internal func ledger(_ before:NumericalWork,_ after:NumericalWork) throws(RuntimeFailure) {
        guard before.budget == after.budget,after.operations >= before.operations,after.iterations >= before.iterations,after.peakScalarStorage >= before.peakScalarStorage else { throw RuntimeFailure(.invalidOwnerAccess,message:"Loaded supplier reset/replaced numerical ledger.",failedSupplierWorkUnavailable:true) }
    }
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension CheckpointedMechanismSleep {
    public func command(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,drive:[Double],generation:UInt64,
                        work:inout NumericalWork) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        let history=try wakeSource(session,expected:expected)
        guard history.commandGeneration < UInt64.max,generation == history.commandGeneration+1,drive.count == history.drive.count,
              drive.allSatisfy({$0.isFinite}),drive != history.drive else { throw RuntimeFailure(.invalidInput,message:"Constant command must change force with the next generation.") }
        return try publishWake(session,expected:expected,history:history,drive:drive,generation:generation,velocity:history.velocity,kind:1,work:&work)
    }
    @inline(never)
    public func impact(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,impulse:MechanismSleepImpulse,
                       work:inout NumericalWork) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        let history=try wakeSource(session,expected:expected)
        let velocity=try impactVelocity(expected:expected,impulse:impulse,work:&work)
        return try publishWake(session,expected:expected,history:history,drive:history.drive,generation:history.commandGeneration,velocity:velocity,kind:2,work:&work)
    }
    @inline(never)
    private func impactVelocity(expected:RuntimeAcceptedState,impulse:MechanismSleepImpulse,
                                work:inout NumericalWork) throws(RuntimeFailure) -> [Double] {
        let source=try admitImpactSource(expected:expected,impulse:impulse,work:&work)
        let original=try impactOriginalSystem(expected:expected,source:source,work:&work)
        let free=try impactFreeVelocity(source:source,original:original,work:&work)
        let incoming=try impactIncomingSystem(source:source,original:original,free:free,work:&work)
        let motion=try impactReconcile(source:source,incoming:incoming,work:&work)
        return try impactAssociation(source:source,original:original,free:free,incoming:incoming,motion:motion,work:&work)
    }
    @inline(never)
    private func admitImpactSource(expected:RuntimeAcceptedState,impulse:MechanismSleepImpulse,
                                   work:inout NumericalWork) throws(RuntimeFailure) -> SleepImpactSource {
        guard impulse.model == model.stamp,impulse.time == expected.checkpoint.physical.time,
              impulse.acceptedSequence == expected.checkpoint.acceptedSteps,impulse.layout.coordinateIDs == constraints.layout.coordinateIDs,impulse.layout.dimensions == constraints.layout.dimensions,
              impulse.layout.scales == constraints.layout.scales,impulse.layout.timeScale == constraints.layout.timeScale,impulse.layout.revision == constraints.layout.revision else {
            throw RuntimeFailure(.invalidOwnerAccess,message:"Instantaneous generalized impulse source/layout/time/sequence differs.")
        }
        let physical=expected.checkpoint.physical,n=physical.v.count
        let reserved=try sleepNumerical { () throws(NumericalError) in try NumericalWork.sum(try NumericalWork.product(128,model.tree.bodies.count),try NumericalWork.sum(try NumericalWork.product(8,try NumericalWork.product(n,n)),try NumericalWork.product(32,n))) }
        try sleepNumerical { () throws(NumericalError) in try work.requireStorage(reserved);try work.chargeOperations(1) }
        return SleepImpactSource(physical:physical,impulse:impulse,count:n,reserved:reserved)
    }
    @inline(never)
    private func impactOriginalSystem(expected:RuntimeAcceptedState,source:SleepImpactSource,
                                      work:inout NumericalWork) throws(RuntimeFailure) -> SleepImpactSystem {
        let physical=source.physical
        let snapshot:KinematicSnapshot,input:RigidDynamicsInput
        do { snapshot=try model.evaluate(expected.physical);input=try RigidDynamicsInput(snapshot:snapshot,velocity:physical.v,inertias:inertias,gravity:nil) }
        catch { throw RuntimeFailure(.invalidState,message:"Generalized impact actual source state failed.") }
        var load:LoadWork
        do { load=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0)) }
        catch { throw RuntimeFailure(.invalidInput,message:"Impact zero external-force budget failed.") }
        do throws(DynamicsError) { let value=try RigidEquationKernel().assemble(input,admission:admission,loadWork:&load,work:&work);return SleepImpactSystem(value,load:load) }
        catch { throw RuntimeFailure(.invalidState,message:"Impact actual mass assembly failed.",failedSupplierWorkUnavailable:MechanismError.dynamics(error).failedSupplierWorkUnavailable) }
    }
    @inline(never)
    private func impactFreeVelocity(source:SleepImpactSource,original:SleepImpactSystem,
                                     work:inout NumericalWork) throws(RuntimeFailure) -> [Double] {
        let physical=source.physical,n=source.count,impulse=source.impulse
        let system=original.value
        let delta:DynamicsSolution
        let massBefore=work
        var produced:DynamicsSolution?,massFailure:DynamicsError?
        do throws(DynamicsError) { produced=try DenseRigidDynamics().inverseMassProduct(system,rightHandSide:impulse.values,policy:solvePolicy.dynamics,work:&work) }
        catch { massFailure=error }
        try sleepLedger(massBefore,work)
        if let massFailure { throw RuntimeFailure(.invalidState,message:"Actual instantaneous mass-inverse impulse failed.",failedSupplierWorkUnavailable:MechanismError.dynamics(massFailure).failedSupplierWorkUnavailable) }
        guard let produced,produced.acceleration.count == n else { throw RuntimeFailure(.invalidState,message:"Impact mass-inverse output shape differs.") };delta=produced
        var free=physical.v
        for i in 0..<n { try sleepNumerical { () throws(NumericalError) in try work.chargeOperations(1) };free[i]+=delta.acceleration[i];guard free[i].isFinite else { throw RuntimeFailure(.invalidState,message:"Impact velocity is nonfinite.") } }
        return free
    }
    @inline(never)
    private func impactIncomingSystem(source:SleepImpactSource,original:SleepImpactSystem,free:[Double],
                                       work:inout NumericalWork) throws(RuntimeFailure) -> SleepImpactIncoming {
        let physical=source.physical,n=source.count
        var load=original.load
        let incomingInput:RigidDynamicsInput,incomingSnapshot:KinematicSnapshot
        do {
            let incomingState=try KinematicState(revision:model.stamp.revision,time:physical.time,q:physical.q,v:free,acceleration:[Double](repeating:0,count:n))
            incomingSnapshot=try model.evaluate(model.makeState(incomingState))
            incomingInput=try RigidDynamicsInput(snapshot:incomingSnapshot,velocity:free,inertias:inertias,gravity:nil)
        }
        catch { throw RuntimeFailure(.invalidState,message:"Impulse velocity source construction failed.") }
        do throws(DynamicsError) { return SleepImpactIncoming(snapshot:incomingSnapshot,system:try RigidEquationKernel().assemble(incomingInput,admission:admission,loadWork:&load,work:&work)) }
        catch { throw RuntimeFailure(.invalidState,message:"Impulse reconciliation actual mass assembly failed.",failedSupplierWorkUnavailable:MechanismError.dynamics(error).failedSupplierWorkUnavailable) }
    }
    @inline(never)
    private func impactReconcile(source:SleepImpactSource,incoming:SleepImpactIncoming,
                                 work:inout NumericalWork) throws(RuntimeFailure) -> SleepImpactMotion {
        let reserved=source.reserved
        let sample=VelocityConstraintSample(layout:constraints.layout,rowIDs:constraints.rows.map({$0.id}),rows:constraints.rows.flatMap({$0.linear}),
            drift:[Double](repeating:0,count:constraints.rows.count),accelerationBias:[Double](repeating:0,count:constraints.rows.count),isIntegrable:true)
        let budget=try sleepNumerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        var outer=NumericalWork(budget:budget),dynamics=NumericalWork(budget:budget),rank=NumericalWork(budget:budget),linear=NumericalWork(budget:budget)
        let before=[outer,dynamics,rank,linear]
        var result:ConstrainedMotion?,failure:MechanismError?
        do throws(MechanismError) { result=try MassWeightedMechanismSolver().reconcileVelocity(incoming.system,sample:sample,policy:solvePolicy,
            work:&outer,dynamicsWork:&dynamics,rankWork:&rank,linearWork:&linear) } catch { failure=error }
        for (prior,ledger) in zip(before,[outer,dynamics,rank,linear]) { try sleepLedger(prior,ledger);try sleepNumerical { () throws(NumericalError) in try work.absorb(ledger,reservedStorage:reserved) } }
        if let failure { throw RuntimeFailure(.invalidState,message:"Actual constrained impact reconciliation failed.",failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable) }
        guard let result else { throw RuntimeFailure(.invalidState,message:"Constrained impulse meaning or actual physical source differs.") }
        return SleepImpactMotion(result)
    }
    @inline(never)
    private func impactAssociation(source:SleepImpactSource,original:SleepImpactSystem,free:[Double],incoming:SleepImpactIncoming,
                                   motion:SleepImpactMotion,work:inout NumericalWork) throws(RuntimeFailure) -> [Double] {
        let result=motion.value,physical=source.physical,n=source.count,impulse=source.impulse,system=original.value
        guard result.temporalMeaning == .instantaneousVelocityImpulse,result.values.count == n,result.generalizedReaction.count == n,
              result.sourceVelocity == free,result.sourceSnapshot.bodies == incoming.snapshot.bodies,result.time == physical.time,result.basis == model.tree.layout else {
            throw RuntimeFailure(.invalidState,message:"Constrained impulse meaning or actual physical source differs.")
        }
        for i in 0..<n {
            var momentum=0.0
            for j in 0..<n { try sleepNumerical { () throws(NumericalError) in try work.chargeOperations(3) };momentum+=system.massMatrix[i*n+j]*(result.values[j]-physical.v[j]) }
            let residual=abs(momentum-impulse.values[i]-result.generalizedReaction[i])*constraints.layout.scales[i]/(solvePolicy.dynamics.energyScale*constraints.layout.timeScale)
            guard residual.isFinite,residual <= solvePolicy.originalTolerance else { throw RuntimeFailure(.invalidState,message:"Original instantaneous M delta-v does not match applied plus constraint impulse.") }
        }
        return result.values
    }
    private func wakeSource(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState) throws(RuntimeFailure) -> MechanismSleepHistory {
        try sleepCheck()
        guard session.snapshot() == expected,expected.physical.stamp == model.stamp,expected.checkpoint.acceptedSteps < UInt64.max,
              let record=expected.checkpoint.contributors.first(where:{$0.id == schema.id}) else { throw RuntimeFailure(.invalidOwnerAccess,message:"Wake accepted source/model/sequence changed.") }
        return try associated(record,physical:expected.checkpoint.physical,sequence:expected.checkpoint.acceptedSteps)
    }
    @inline(never)
    private func publishWake(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,history:MechanismSleepHistory,drive:[Double],generation:UInt64,
                             velocity:[Double],kind:UInt64,work:inout NumericalWork) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        let context=try prepareWake(expected:expected,history:history,drive:drive,generation:generation,velocity:velocity,kind:kind,work:&work)
        var result:RuntimeTrialOutcome?,failure:RuntimeFailure?
        do throws(RuntimeFailure) { result=try runWake(session,context:context) } catch { failure=error }
        try sleepNumerical { () throws(NumericalError) in try work.absorb(context.ledger.read(),reservedStorage:context.reserved) }
        if let failure { throw failure }
        guard let result else { throw RuntimeFailure(.invalidState,message:"Wake transaction has no outcome.") };return result
    }
    @inline(never)
    private func prepareWake(expected:RuntimeAcceptedState,history:MechanismSleepHistory,drive:[Double],generation:UInt64,
                             velocity:[Double],kind:UInt64,work:inout NumericalWork) throws(RuntimeFailure) -> SleepWakeContext {
        let n=history.position.count
        let reserved=try sleepNumerical { () throws(NumericalError) in try NumericalWork.sum(try NumericalWork.product(16,n),try NumericalWork.sum(schema.maximumBytes,continuation.schema.maximumBytes)) }
        try sleepNumerical { () throws(NumericalError) in try work.requireStorage(reserved) }
        let budget=try sleepNumerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserved) }
        let ledger=SleepNumericalLedger(NumericalWork(budget:budget)),equation=try equation(drive:drive)
        var point=history.position;point.append(contentsOf:velocity)
        let sequence=history.acceptedSequence+1
        let updated=MechanismSleepHistory(time:history.acceptedTime,sequence:sequence,q:history.position,v:velocity,drive:drive,generation:generation,
            asleep:[Bool](repeating:false,count:n),restSince:[Double](repeating:history.acceptedTime,count:n),wakeSequence:sequence,kind:kind,coordinates:[Bool](repeating:true,count:n))
        let adapter=try SleepMechanismEquation(owner:self,source:expected,history:updated)
        return SleepWakeContext(expected:expected,history:history,updated:updated,velocity:velocity,target:point,equation:equation,adapter:adapter,ledger:ledger,reserved:reserved)
    }
    @inline(never)
    private func runWake(_ session:any RuntimeSessionOperating,context:SleepWakeContext) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
            try self.validateWakeSource(session,context:context,trial:trial,control:&control)
            var work=context.ledger.read();defer { context.ledger.store(work) }
            let derivative=try self.wakeDerivative(context:context,work:&work,control:control)
            try self.publishWakeEndpoint(context:context,derivative:derivative,trial:&trial)
            return .accept
        }
    }
    @inline(never)
    private func validateWakeSource(_ session:any RuntimeSessionOperating,context:SleepWakeContext,trial:RuntimeTrial,
                                     control:inout RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1);try sleepCheck()
        guard session.snapshot() == context.expected,trial.timeSeconds == context.history.acceptedTime else { throw RuntimeFailure(.invalidOwnerAccess,message:"Wake source changed before physical publication.") }
        for i in context.history.position.indices {
            try control.beginWorkBlock(units:1)
            guard try trial.position(at:i) == context.history.position[i],try trial.velocity(at:i) == context.history.velocity[i] else { throw RuntimeFailure(.invalidOwnerAccess,message:"Wake physical source differs.") }
        }
    }
    @inline(never)
    private func wakeDerivative(context:SleepWakeContext,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> [Double] {
        try sleepNumerical { () throws(NumericalError) in try work.chargeOperations(1) }
        let before=work
        var derivative=[Double](repeating:.nan,count:context.target.count),failure:RuntimeFailure?
        do throws(RuntimeFailure) { try context.equation.derivative(time:context.history.acceptedTime,point:context.target,into:&derivative,work:&work,control:control) }
        catch { failure=error }
        try sleepLedger(before,work)
        if let failure { throw failure }
        return derivative
    }
    @inline(never)
    private func publishWakeEndpoint(context:SleepWakeContext,derivative:[Double],trial:inout RuntimeTrial) throws(RuntimeFailure) {
        try context.equation.write(point:context.target,derivative:derivative,time:context.history.acceptedTime,trial:&trial)
        let physical:KinematicState
        do { physical=try KinematicState(revision:model.stamp.revision,time:context.history.acceptedTime,q:context.history.position,v:context.velocity,acceleration:Array(derivative[context.history.position.count...])) }
        catch { throw RuntimeFailure(.invalidState,message:"Wake endpoint physical state failed.") }
        try trial.replaceContributor(record(context.updated))
        try trial.replaceContributor(continuation.initialRecord(physical:physical,equations:context.adapter))
    }
}

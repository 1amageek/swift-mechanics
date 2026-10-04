@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension LoadedCheckpointedMechanismSleep {
    public func selectLoad(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,selection:StationaryLoadSelection,loadBudget:LoadBudget,maximumLoadInvocations:Int,work:inout NumericalWork) throws(LoadedMechanismSleepFailure) -> LoadedMechanismWakeResult {
        try loadedWake(session,expected:expected,selection:selection,drive:nil,generation:nil,impulse:nil,loadBudget:loadBudget,maximumLoadInvocations:maximumLoadInvocations,work:&work)
    }
    public func commandWithLoads(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,drive:[Double],generation:UInt64,loadBudget:LoadBudget,maximumLoadInvocations:Int,work:inout NumericalWork) throws(LoadedMechanismSleepFailure) -> LoadedMechanismWakeResult {
        try loadedWake(session,expected:expected,selection:nil,drive:drive,generation:generation,impulse:nil,loadBudget:loadBudget,maximumLoadInvocations:maximumLoadInvocations,work:&work)
    }
    public func impactWithLoads(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,impulse:MechanismSleepImpulse,loadBudget:LoadBudget,maximumLoadInvocations:Int,work:inout NumericalWork) throws(LoadedMechanismSleepFailure) -> LoadedMechanismWakeResult {
        try loadedWake(session,expected:expected,selection:nil,drive:nil,generation:nil,impulse:impulse,loadBudget:loadBudget,maximumLoadInvocations:maximumLoadInvocations,work:&work)
    }
    @inline(never)
    private func loadedWake(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,selection:StationaryLoadSelection?,drive:[Double]?,generation:UInt64?,impulse:MechanismSleepImpulse?,loadBudget:LoadBudget,maximumLoadInvocations:Int,work:inout NumericalWork) throws(LoadedMechanismSleepFailure) -> LoadedMechanismWakeResult {
        let execution:StationaryLoadExecution
        do throws(StationaryLoadError) { execution=try StationaryLoadExecution(scope:.equationExecution,budget:loadBudget,maximumInvocations:maximumLoadInvocations,requiredScalars:model.tree.layout.velocityCount) }
        catch { throw .preflight(error.runtimeFailure,accepted:expected,loads:.notAdmitted(scope:.equationExecution,budget:loadBudget,maximumInvocations:maximumLoadInvocations)) }
        do throws(RuntimeFailure) {
            let context=try prepareLoadedWake(session,expected:expected,selection:selection,drive:drive,generation:generation,impulse:impulse,execution:execution,work:&work)
            let outcome=try publishLoadedWake(session,context:context,work:&work)
            return LoadedMechanismWakeResult(outcome:outcome,loads:execution.close())
        } catch { throw .wake(error,accepted:session.snapshot(),loads:execution.close()) }
    }
    @inline(never)
    private func prepareLoadedWake(_ session:any RuntimeSessionOperating,expected:RuntimeAcceptedState,selection:StationaryLoadSelection?,drive:[Double]?,generation:UInt64?,impulse:MechanismSleepImpulse?,execution:StationaryLoadExecution,work:inout NumericalWork) throws(RuntimeFailure) -> LoadedSleepWakeContext {
        try check()
        guard session.snapshot() == expected,expected.physical.stamp == model.stamp,expected.checkpoint.acceptedSteps < UInt64.max,
              let record=expected.checkpoint.contributors.first(where:{$0.id == schema.id}) else { throw RuntimeFailure(.invalidOwnerAccess,message:"Loaded wake source/model/sequence changed.") }
        let history=try associated(record,physical:expected.checkpoint.physical,sequence:expected.checkpoint.acceptedSteps),h=history.mechanics
        var nextSelection=history.selection,nextDrive=h.drive,nextGeneration=h.commandGeneration,velocity=h.velocity,kind:UInt64=0
        var previous=history.previousProgramID,previousRevision=history.previousRevision
        if let selection {
            guard history.selection.generation < UInt64.max,selection.generation == history.selection.generation+1,
                  selection.programID != history.selection.programID || selection.revision != history.selection.revision else { throw RuntimeFailure(.invalidInput,message:"Load selection requires a changed program and next generation.") }
            do throws(StationaryLoadError) { _=try catalog.program(selection) } catch { throw error.runtimeFailure }
            nextSelection=selection;previous=history.selection.programID;previousRevision=history.selection.revision;kind=3
        } else if let drive,let generation {
            guard h.commandGeneration < UInt64.max,generation == h.commandGeneration+1,drive.count == h.drive.count,drive != h.drive,drive.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidInput,message:"Loaded command must change actual force with next generation.") }
            nextDrive=drive;nextGeneration=generation;kind=1
        } else if let impulse {
            velocity=try loadedImpactVelocity(expected:expected,impulse:impulse,work:&work);kind=2
        } else { throw RuntimeFailure(.invalidInput,message:"Loaded wake has no physical authority.") }
        let sequence=h.acceptedSequence+1,n=h.position.count
        let updated=LoadedMechanismSleepHistory(mechanics:MechanismSleepHistory(time:h.acceptedTime,sequence:sequence,q:h.position,v:velocity,drive:nextDrive,generation:nextGeneration,asleep:[Bool](repeating:false,count:n),restSince:[Double](repeating:h.acceptedTime,count:n),wakeSequence:sequence,kind:kind,coordinates:[Bool](repeating:true,count:n)),selection:nextSelection,previousProgramID:previous,previousRevision:previousRevision)
        let reserved=try numerical { () throws(NumericalError) in try NumericalWork.sum(try NumericalWork.product(16,n),try NumericalWork.sum(schema.maximumBytes,continuation.schema.maximumBytes)) }
        try numerical { () throws(NumericalError) in try work.requireStorage(reserved) }
        let local=try numerical { () throws(NumericalError) in NumericalWork(budget:try work.remainingBudget(reservedStorage:reserved)) }
        let equation=try equation(drive:nextDrive,selection:nextSelection,execution:execution)
        let adapter=try LoadedSleepMechanismEquation(owner:self,source:expected,history:updated,execution:execution)
        return LoadedSleepWakeContext(source:expected,original:history,updated:updated,equation:equation,adapter:adapter,ledger:SleepNumericalLedger(local),reserved:reserved)
    }
    @inline(never)
    private func publishLoadedWake(_ session:any RuntimeSessionOperating,context:LoadedSleepWakeContext,work:inout NumericalWork) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        var outcome:RuntimeTrialOutcome?,failure:RuntimeFailure?
        do throws(RuntimeFailure) { outcome=try runLoadedWake(session,context:context) } catch { failure=error }
        try numerical { () throws(NumericalError) in try work.absorb(context.ledger.read(),reservedStorage:context.reserved) }
        if let failure { throw failure };guard let outcome else { throw RuntimeFailure(.invalidState,message:"Loaded wake produced no transaction outcome.") };return outcome
    }
    @inline(never)
    private func runLoadedWake(_ session:any RuntimeSessionOperating,context:LoadedSleepWakeContext) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        try session.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) in
            try self.validateLoadedWake(session,context:context,trial:trial,control:&control)
            var numerical=context.ledger.read();defer { context.ledger.store(numerical) }
            let derivative=try self.loadedWakeDerivative(context:context,work:&numerical,control:control)
            try self.publishLoadedEndpoint(context:context,derivative:derivative,trial:&trial)
            return .accept
        }
    }
    @inline(never)
    private func validateLoadedWake(_ session:any RuntimeSessionOperating,context:LoadedSleepWakeContext,trial:RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1);try check();let h=context.original.mechanics
        guard session.snapshot() == context.source,trial.timeSeconds == h.acceptedTime,
              let expected=context.source.checkpoint.contributors.first(where:{$0.id == schema.id}),try trial.contributor(schema.id) == expected else { throw RuntimeFailure(.invalidOwnerAccess,message:"Loaded wake original authority changed before publication.") }
        for i in h.position.indices { try control.beginWorkBlock(units:1);guard try trial.position(at:i) == h.position[i],try trial.velocity(at:i) == h.velocity[i] else { throw RuntimeFailure(.invalidOwnerAccess,message:"Loaded wake physical q/v source changed.") } }
    }
    @inline(never)
    private func loadedWakeDerivative(context:LoadedSleepWakeContext,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) -> [Double] {
        let h=context.updated.mechanics,point=h.position+h.velocity
        var derivative=[Double](repeating:.nan,count:point.count)
        try context.equation.derivative(time:h.acceptedTime,point:point,into:&derivative,work:&work,control:control)
        return derivative
    }
    @inline(never)
    private func publishLoadedEndpoint(context:LoadedSleepWakeContext,derivative:[Double],trial:inout RuntimeTrial) throws(RuntimeFailure) {
        let h=context.updated.mechanics
        try context.equation.write(point:h.position+h.velocity,derivative:derivative,time:h.acceptedTime,trial:&trial)
        let physical:KinematicState
        do { physical=try KinematicState(revision:model.stamp.revision,time:h.acceptedTime,q:h.position,v:h.velocity,acceleration:Array(derivative[h.position.count...])) }
        catch { throw RuntimeFailure(.invalidState,message:"Loaded wake physical endpoint failed.") }
        try trial.replaceContributor(record(context.updated))
        try trial.replaceContributor(continuation.initialRecord(physical:physical,equations:context.adapter))
    }
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct LoadedSleepRuntimeContributors:RuntimeContributorHandling,Sendable {
    let owner:LoadedCheckpointedMechanismSleep
    let physical:KinematicState
    let sequence:UInt64
    let receipt:LoadedSleepValidationReceipt
    let cancellation:RuntimeCancellationSource?
    var schemas:[RuntimeContributorSchema] { owner.schemas }
    func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        try owner.check()
        guard model.stamp == owner.model.stamp,model.descriptor == owner.model.descriptor,model.tree.layout == owner.model.tree.layout else { throw RuntimeFailure(.incompatibleModel,message:"Loaded checkpoint actual model authority differs.") }
        if record.id == owner.continuation.schema.id {
            let evidence=try owner.continuation.validate(record,model:model,budget:budget)
            let h=try owner.continuation.history(record)
            guard h.acceptedTime == physical.time,h.acceptedPoint == physical.q+physical.v else { throw RuntimeFailure(.invalidContributor,message:"Loaded integration history differs from actual physical q/v/time.") };return evidence
        }
        guard record.id == owner.schema.id,record.bytes.count <= budget.workUnits,record.bytes.count <= budget.scratchBytes else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Loaded record decoding exceeds admitted capacity.") }
        let h=try owner.associated(record,physical:physical,sequence:sequence)
        if !h.mechanics.asleep.contains(true) {
            let zero:LoadBudget
            do throws(LoadError) { zero=try LoadBudget(maximumWork:0,maximumScalars:0) } catch { throw RuntimeFailure(.invalidInput,message:"Loaded awake receipt admission failed.") }
            receipt.store(.notAdmitted(scope:.checkpointAdmission,budget:zero,maximumInvocations:1))
            return try RuntimeValidationEvidence(workUnitsUsed:record.bytes.count,scratchBytesUsed:record.bytes.count)
        }
        return try validateSleeping(record,history:h,budget:budget)
    }
    @inline(never)
    private func validateSleeping(_ record:RuntimeContributorState,history:LoadedMechanismSleepHistory,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        let program:StationaryLoadProgram
        do throws(StationaryLoadError) { program=try owner.catalog.program(history.selection) } catch { throw error.runtimeFailure }
        let loadAllowance:Int,loadScratch:Int
        do { loadAllowance=try NumericalWork.sum(1,try NumericalWork.sum(program.terms.count,program.gravity == nil ? 0 : owner.model.tree.bodies.count));loadScratch=try NumericalWork.product(8,physical.v.count) }
        catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Loaded validation load reservation overflow.") }
        let baseBytes=record.bytes.count
        guard loadAllowance <= budget.workUnits-baseBytes,loadScratch <= budget.scratchBytes-baseBytes else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Cold load proof cannot fit whole Runtime validation envelope.") }
        let execution:StationaryLoadExecution
        do {
            let loadBudget=try LoadBudget(maximumWork:loadAllowance,maximumScalars:physical.v.count,isCancelled:{
                do { try cancellation?.check();return Task.isCancelled } catch { return true }
            })
            execution=try StationaryLoadExecution(scope:.checkpointAdmission,budget:loadBudget,maximumInvocations:1,requiredScalars:physical.v.count)
        } catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Cold load proof execution admission failed.") }
        defer { receipt.store(execution.close()) }
        var work:NumericalWork
        do { work=NumericalWork(budget:try NumericalBudget(scalarStorage:(budget.scratchBytes-baseBytes-loadScratch)/8,arithmeticOperations:budget.workUnits-baseBytes-loadAllowance,iterations:budget.workUnits-baseBytes-loadAllowance)) }
        catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Cold numerical proof budget admission failed.") }
        let equation=owner.initialEquation
        guard physical.acceleration.allSatisfy({$0 == 0}),let proof=try owner.restProof(physical:physical,history:history,equation:equation,execution:execution,work:&work) else { throw RuntimeFailure(.invalidContributor,message:"Loaded sleeping checkpoint lacks genuine gravity/passive equilibrium.") }
        for group in proof.groups {
            guard let first=group.first,group.allSatisfy({history.mechanics.asleep[$0] == history.mechanics.asleep[first] && history.mechanics.restSince[$0] == history.mechanics.restSince[first]}) else { throw RuntimeFailure(.invalidContributor,message:"Loaded connected sleep history differs.") }
        }
        let actual=execution.report(),used:Int,scratch:Int
        do {
            used=try NumericalWork.sum(baseBytes,try NumericalWork.sum(work.operations,actual.consumed))
            scratch=try NumericalWork.sum(baseBytes,try NumericalWork.product(8,try NumericalWork.sum(work.peakScalarStorage,actual.peakScalars)))
        } catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Cold validation receipt evidence overflow.") }
        return try RuntimeValidationEvidence(workUnitsUsed:used,scratchBytesUsed:scratch)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Model replacement requires separately admitted target catalog/event migration. This owner never carries a prior loaded sleep authority across topology changes.
    func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState { try owner.migrate(record,transition:transition,target:target,budget:budget) }
}

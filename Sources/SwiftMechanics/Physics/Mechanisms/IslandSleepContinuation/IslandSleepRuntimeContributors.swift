@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct IslandSleepRuntimeContributors: RuntimeContributorHandling,Sendable {
    let owner:IslandCheckpointedMechanismSleep
    let checkpoint:RuntimeCheckpoint
    let receipt:IslandSleepAdmissionReceipt
    let cancellation:RuntimeCancellationSource?
    var schemas:[RuntimeContributorSchema] { owner.schemas }
    @inline(never)
    func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        try cancellation?.check();try owner.check()
        guard owner.sameModel(model) else { throw RuntimeFailure(.incompatibleModel,message:"Mixed actual source model differs.") }
        if record.id == owner.continuation.schema.id {
            let evidence=try owner.continuation.validate(record,model:model,budget:budget),h=try owner.continuation.history(record)
            guard h.acceptedTime.bitPattern == checkpoint.physical.time.bitPattern,IslandSleepBits.equal(h.acceptedPoint,checkpoint.physical.q+checkpoint.physical.v),h.acceptedSteps == checkpoint.acceptedSteps else { throw RuntimeFailure(.invalidContributor,message:"Mixed integration actual q/v/time/global history differs.") };return evidence
        }
        if let participant=owner.participant,record.id == owner.participantSchema?.id {
            try owner.checkParticipant()
            let evidence=try participant.validateAssociation(record:record,physical:checkpoint.physical,acceptedSequence:checkpoint.acceptedSteps,budget:budget)
            try owner.checkParticipant();return evidence
        }
        guard record.id == owner.schema.id,record.bytes.count <= budget.workUnits,record.bytes.count <= budget.scratchBytes else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Mixed decoding exceeds validation bounds.") }
        let h=try owner.associated(record,physical:checkpoint.physical,sequence:checkpoint.acceptedSteps)
        return try validatePhysical(h,budget:budget,bytes:record.bytes.count)
    }
    @inline(never)
    private func validatePhysical(_ history:IslandSleepHistory,budget:RuntimeValidationBudget,bytes:Int) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        let allowance=(budget.workUnits-bytes)/3,scratch=(budget.scratchBytes-bytes)/16
        let work:IslandSleepWork
        do {
            let numerical=NumericalWork(budget:try NumericalBudget(scalarStorage:scratch,arithmeticOperations:allowance,iterations:allowance))
            let loads=LoadWork(budget:try LoadBudget(maximumWork:allowance,maximumScalars:scratch,isCancelled:{
                do throws(RuntimeFailure) { try cancellation?.check();return Task.isCancelled || owner.policy.thresholds.isCancelled() } catch { return true }
            }))
            work=IslandSleepWork(physical:StationaryIslandWork(numerical:numerical,loads:loads),contributorEncoding:NumericalWork(budget:try NumericalBudget(scalarStorage:0,arithmeticOperations:0,iterations:0)))
        } catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Mixed cold validation envelope could not be admitted.") }
        let execution=IslandSleepExecution(work:work,maximum:owner.operationPolicy.maximumSupplierInvocations)
        defer { receipt.store(execution.read()) }
        try actualPhysical(history,execution:execution,budget:work.physical.numerical.budget)
        let actual=execution.read(),used=try IslandSleepBits.sum(bytes,try IslandSleepBits.sum(actual.physical.numerical.operations,try IslandSleepBits.sum(actual.physical.numerical.iterations,actual.physical.loads.consumed)))
        let storage=try IslandSleepBits.sum(bytes,try IslandSleepBits.product(8,try IslandSleepBits.sum(actual.physical.numerical.peakScalarStorage,actual.physical.loads.peakScalars)))
        guard used <= budget.workUnits,storage <= budget.scratchBytes else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Mixed cold proof exceeded original validation envelope.") }
        return try RuntimeValidationEvidence(workUnitsUsed:used,scratchBytesUsed:storage)
    }
    @inline(never)
    private func actualPhysical(_ history:IslandSleepHistory,execution:IslandSleepExecution,budget:NumericalBudget) throws(RuntimeFailure) {
        var work=NumericalWork(budget:budget),proofs=[StationaryIslandRestCertificate?](repeating:nil,count:owner.program.islands.count)
        for j in owner.program.islands.indices where history.asleep[j] {
            try cancellation?.check();proofs[j]=try owner.proof(index:j,physical:checkpoint.physical,execution:execution,work:&work)
            guard proofs[j] != nil,owner.program.islands[j].sourceCoordinateIndices.allSatisfy({checkpoint.physical.acceleration[$0] == 0}) else { throw RuntimeFailure(.invalidContributor,message:"Mixed sleeping checkpoint lacks actual cold rest/zero acceleration.") }
        }
        let acceleration=try owner.acceleration(physical:checkpoint.physical,flags:history.asleep,proofs:proofs,execution:execution,work:&work)
        guard zip(acceleration,checkpoint.physical.acceleration).allSatisfy({pair in pair.0.bitPattern == pair.1.bitPattern || pair.0 == 0 && pair.1 == 0}) else { throw RuntimeFailure(.invalidContributor,message:"Mixed awake acceleration differs from actual stationary force.") }
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): This contextual provider has no mapped topology/law target authority. Generic migration must remain refused until the accepted topology owner proves target histories and force.
    func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState { try owner.migrate(record,transition:transition,target:target,budget:budget) }
}

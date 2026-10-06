@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension IslandCheckpointedMechanismSleep {
    @inline(never)
    public func step(_ session:any RuntimeSessionOperating,work:inout IslandSleepWork) throws(IslandSleepFailure) -> IslandSleepAdvanceResult {
        let execution=IslandSleepExecution(work:work,maximum:operationPolicy.maximumSupplierInvocations)
        defer { work=execution.read() }
        let adapter:IslandSleepMechanismEquation
        do throws(RuntimeFailure) { adapter=try stepAdapter(source:session.snapshot(),execution:execution) }
        catch { throw IslandSleepFailure(.runtime(error),accepted:session.snapshot(),work:execution.read()) }
        return try integrateStep(session,adapter:adapter,execution:execution)
    }
    @inline(never)
    internal func stepAdapter(source:RuntimeAcceptedState,execution:IslandSleepExecution) throws(RuntimeFailure) -> IslandSleepMechanismEquation {
        try check();guard source.physical.stamp == model.stamp,source.checkpoint.acceptedSteps < UInt64.max,
              source.checkpoint.contributors.count == schemas.count,let record=source.checkpoint.contributors.first(where:{$0.id == schema.id}),let integration=source.checkpoint.contributors.first(where:{$0.id == continuation.schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Whole mixed accepted source/history is incomplete.") }
        let h=try associated(record,physical:source.checkpoint.physical,sequence:source.checkpoint.acceptedSteps),ih=try continuation.history(integration)
        guard ih.acceptedSteps == h.acceptedSequence,ih.acceptedTime.bitPattern == h.acceptedTime.bitPattern,IslandSleepBits.equal(ih.acceptedPoint,h.position+h.velocity) else { throw RuntimeFailure(.invalidContributor,message:"Mixed integration source association differs.") }
        try checkParticipant()
        if let participant,let schema=participantSchema,let record=source.checkpoint.contributors.first(where:{$0.id == schema.id}) {
            try execution.encode { (work:inout NumericalWork) throws(RuntimeFailure) in
                let budget=try RuntimeValidationBudget(workUnits:work.budget.arithmeticOperations-work.operations,scratchBytes:work.budget.scalarStorage)
                let evidence=try participant.validateAssociation(record:record,physical:source.checkpoint.physical,acceptedSequence:h.acceptedSequence,budget:budget)
                try checkParticipant()
                guard evidence.workUnitsUsed <= budget.workUnits,evidence.scratchBytesUsed <= budget.scratchBytes else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Mixed participant source evidence exceeded budget.",failedSupplierWorkUnavailable:true) }
                do throws(NumericalError) { try work.requireStorage(evidence.scratchBytesUsed);try work.chargeOperations(evidence.workUnitsUsed) }
                catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Participant source receipt could not fit.",failedSupplierWorkUnavailable:true) }
            }
        }
        return IslandSleepMechanismEquation(owner:self,source:source,history:h,execution:execution)
    }
    @inline(never)
    private func integrateStep(_ session:any RuntimeSessionOperating,adapter:IslandSleepMechanismEquation,execution:IslandSleepExecution) throws(IslandSleepFailure) -> IslandSleepAdvanceResult {
        do throws(IntegrationFailure) {
            let actual=try ReferenceExplicitIntegrator().step(session,model:model,equations:adapter,continuation:continuation)
            return IslandSleepAdvanceResult(integration:actual,work:execution.read())
        } catch { throw IslandSleepFailure(.integration(error),accepted:error.lastAccepted,work:execution.read(),supplierFailure:execution.failure()) }
    }
}

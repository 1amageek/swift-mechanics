@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension IslandCheckpointedMechanismSleep {
    @inline(never)
    public func prepareSmoothEndpoint(source:RuntimeAcceptedState,endpoint:IslandSleepTrajectoryEndpoint,work:inout IslandSleepWork) throws(IslandSleepFailure) -> PreparedIslandSmoothEndpoint {
        let execution=IslandSleepExecution(work:work,maximum:operationPolicy.maximumSupplierInvocations)
        defer { work=execution.read() }
        do throws(RuntimeFailure) {
            _=try stepAdapter(source:source,execution:execution)
            guard endpoint.owner === self,endpoint.source == source.checkpoint,source.checkpoint.acceptedSteps < UInt64.max,endpoint.physical.time > source.checkpoint.physical.time,
                  endpoint.accepted.checkpoint.model == source.checkpoint.model,endpoint.accepted.checkpoint.random == source.checkpoint.random,
                  let original=source.checkpoint.contributors.first(where:{$0.id == schema.id}),
                  let record=endpoint.accepted.checkpoint.contributors.first(where:{$0.id == schema.id}),
                  let integrated=endpoint.accepted.checkpoint.contributors.first(where:{$0.id == continuation.schema.id}) else {
                throw RuntimeFailure(.invalidContributor,message:"Smooth endpoint owner/original source/time/whole histories differ.")
            }
            let old=try history(original),actual=try associated(record,physical:endpoint.physical,sequence:endpoint.accepted.checkpoint.acceptedSteps),ih=try continuation.history(integrated)
            guard ih.acceptedSteps == actual.acceptedSequence,ih.acceptedTime.bitPattern == actual.acceptedTime.bitPattern,IslandSleepBits.equal(ih.acceptedPoint,actual.position+actual.velocity),
                  actual.wakeSequence == old.wakeSequence,actual.lastWakeTime.bitPattern == old.lastWakeTime.bitPattern,actual.lastWakeEventID == old.lastWakeEventID,actual.lastWakeKind == old.lastWakeKind,actual.lastWakeIslands == old.lastWakeIslands else {
                throw RuntimeFailure(.invalidContributor,message:"Smooth query changed original wake identity or integration association.")
            }
            return try encodeSmooth(source:source,endpoint:endpoint,history:actual,integration:ih,execution:execution)
        } catch { throw IslandSleepFailure(execution.failure() ?? .runtime(error),accepted:source,work:execution.read()) }
    }
    @inline(never)
    private func encodeSmooth(source:RuntimeAcceptedState,endpoint:IslandSleepTrajectoryEndpoint,history h:IslandSleepHistory,integration ih:IntegrationHistory,execution:IslandSleepExecution) throws(RuntimeFailure) -> PreparedIslandSmoothEndpoint {
        try execution.reserveEncoding(schema.maximumBytes)
        return try execution.encode { (work:inout NumericalWork) throws(RuntimeFailure) in
            do throws(NumericalError) { try work.requireStorage(schema.maximumBytes);try work.chargeOperations(schema.maximumBytes) }
            catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Smooth endpoint encoding exhausted.") }
            let next=source.checkpoint.acceptedSteps+1
            let history=IslandSleepHistory(time:h.acceptedTime,sequence:next,q:h.position,v:h.velocity,ids:h.islandIDs,asleep:h.asleep,since:h.restSince,wakeSequence:h.wakeSequence,wakeTime:h.lastWakeTime,eventID:h.lastWakeEventID,kind:h.lastWakeKind,affected:h.lastWakeIslands)
            let sleep=try record(history),integration=try continuation.record(acceptedTime:ih.acceptedTime,point:ih.acceptedPoint,nextStep:ih.nextStep,acceptedSteps:next,normalizedError:ih.normalizedError)
            return PreparedIslandSmoothEndpoint(owner:self,source:source.checkpoint,physical:endpoint.physical,sleep:sleep,integration:integration)
        }
    }
}

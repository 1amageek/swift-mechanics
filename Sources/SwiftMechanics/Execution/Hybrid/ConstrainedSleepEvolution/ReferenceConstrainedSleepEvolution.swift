@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class ReferenceConstrainedSleepEvolution: ConstrainedSleepEvolving, Sendable {
    internal let sleep:any IslandMechanismSleepContinuing
    internal let environment:any ConstrainedSleepEventEnvironment
    internal let continuation:ConstrainedSleepEventContinuation
    internal let configuration:RuntimeConfiguration
    internal let checkpoints:any IslandSleepCheckpointAdmitting
    internal let preparing:any ConstrainedImpactPreparing
    internal let impulses:any ConstrainedNormalImpulseSolving
    public init(sleep:any IslandMechanismSleepContinuing,environment:any ConstrainedSleepEventEnvironment,continuation:ConstrainedSleepEventContinuation,configuration:RuntimeConfiguration,checkpoints:any IslandSleepCheckpointAdmitting,
                preparing:any ConstrainedImpactPreparing = ReferenceConstrainedImpactPreparer(),impulses:any ConstrainedNormalImpulseSolving = ReferenceConstrainedNormalImpulseSolver()) throws(RuntimeFailure) {
        guard sleep.program.binding == environment.program.binding,continuation.program.binding == sleep.program.binding,environment.catalog == continuation.catalog,
              configuration.requiredContributors == sleep.schemas.sorted(by:{$0.id < $1.id}),sleep.schemas.contains(continuation.schema) else { throw RuntimeFailure(.invalidContributor,message:"Constrained evolution program/catalog/full registration differs.") }
        self.sleep=sleep;self.environment=environment;self.continuation=continuation;self.configuration=configuration;self.checkpoints=checkpoints;self.preparing=preparing;self.impulses=impulses
    }
    @inline(never)
    public func advanceToNextImpact(_ session:any RuntimeSessionOperating,through limit:Double,work initial:ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionFailure) -> ConstrainedSleepEvolutionResult {
        var work=initial
        do throws(ConstrainedSleepEvolutionCause) {
            try check(cancellation);let source=try sourceContext(session,through:limit,work:&work)
            if source.accepted.checkpoint.physical.time == limit { return ConstrainedSleepEvolutionResult(accepted:source.accepted,impact:nil,work:work) }
            let publication=try compute(source,through:limit,work:&work,cancellation:cancellation)
            let accepted=try publish(publication,session:session,cancellation:cancellation)
            work.acceptedSegments+=1;if publication.impact != nil { work.acceptedImpacts+=1 }
            return ConstrainedSleepEvolutionResult(accepted:accepted,impact:publication.impact,work:work)
        } catch {
            if case .impact(let failure)=error { work.failedSupplierWorkUnavailable = work.failedSupplierWorkUnavailable || failure.failedSupplierWorkUnavailable }
            if case .sleep(let failure)=error { work.failedSupplierWorkUnavailable = work.failedSupplierWorkUnavailable || failure.work.failedSupplierWorkUnavailable }
            throw ConstrainedSleepEvolutionFailure(cause:error,accepted:session.snapshot(),work:work)
        }
    }
    internal func check(_ cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) { do throws(HybridError) { try cancellation.check() } catch { throw .hybrid(error) } }
    @inline(never)
    private func sourceContext(_ session:any RuntimeSessionOperating,through time:Double,work:inout ConstrainedSleepEvolutionWork) throws(ConstrainedSleepEvolutionCause) -> ConstrainedSleepSource {
        let accepted=session.snapshot()
        guard time.isFinite,time>=accepted.checkpoint.physical.time,accepted.checkpoint.acceptedSteps<UInt64.max,work.acceptedSegments<Int.max,work.acceptedImpacts<Int.max,!work.failedSupplierWorkUnavailable,!work.islands.failedSupplierWorkUnavailable else { throw .hybrid(.invalidInput) }
        let report:IslandSleepAdmissionResult
        do throws(IslandSleepAdmissionFailure) { report=try checkpoints.admitWithReport(accepted.checkpoint,model:sleep.model,configuration:configuration,cancellation:nil) }
        catch { work.checkpointAdmission=error.checkpointAdmission;throw .runtime(error.cause) }
        work.checkpointAdmission=report.checkpointAdmission
        guard report.accepted == accepted,let event=accepted.checkpoint.contributors.first(where:{$0.id == continuation.schema.id}),let sleepRecord=accepted.checkpoint.contributors.first(where:{$0.id == sleep.schema.id}) else { throw .hybrid(.invalidContinuation) }
        let history:ConstrainedSleepEventHistory,sleepHistory:IslandSleepHistory
        do throws(RuntimeFailure) { history=try continuation.associated(event,physical:accepted.checkpoint.physical,sequence:accepted.checkpoint.acceptedSteps);sleepHistory=try sleep.history(sleepRecord) } catch { throw .runtime(error) }
        if time>accepted.checkpoint.physical.time {
            // FIXME(INCOMPLETE_IMPLEMENTATION): A new crossing coverage after an accepted jump or an initially awake gear is outside this one-contact resting-gear chart. e0 support and general moving-gear recollision need real coverage/support authority before successful continuation here; genuine IslandSleep stepping remains separate.
            guard history.impactCount == 0,sleep.program.islands.indices.filter({!sleep.program.islands[$0].retainedRowIDs.isEmpty}).allSatisfy({sleepHistory.asleep[$0]}) else { throw .hybrid(.unsupportedDomain) }
        }
        return ConstrainedSleepSource(accepted:accepted,history:history)
    }
    @inline(never)
    private func compute(_ source:ConstrainedSleepSource,through limit:Double,work:inout ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) -> ConstrainedSleepPublication {
        if let endpoint=try locate(source,through:limit,work:&work,cancellation:cancellation) { return try impactPublication(source,endpoint:endpoint,work:&work,cancellation:cancellation) }
        let endpoint=try query(source,to:limit,work:&work,cancellation:cancellation)
        let prepared:PreparedIslandSmoothEndpoint
        do throws(IslandSleepFailure) { prepared=try sleep.prepareSmoothEndpoint(source:source.accepted,endpoint:endpoint,work:&work.islands) } catch { throw .sleep(error) }
        let event:RuntimeContributorState
        do throws(RuntimeFailure) { event=try continuation.recordEndpoint(source:source.accepted.checkpoint,physical:prepared.physical,acceptedSequence:source.accepted.checkpoint.acceptedSteps+1,work:&work.numerical) } catch { throw .runtime(error) }
        return ConstrainedSleepPublication(source:source.accepted.checkpoint,physical:prepared.physical,records:[prepared.integration,prepared.sleep,event],impact:nil)
    }
    @inline(never)
    internal func query(_ source:ConstrainedSleepSource,to time:Double,work:inout ConstrainedSleepEvolutionWork,cancellation:HybridCancellation) throws(ConstrainedSleepEvolutionCause) -> IslandSleepTrajectoryEndpoint {
        try check(cancellation);guard work.queries < continuation.policy.maximumQueries else { throw .hybrid(.capacityExceeded) }
        work.queries+=1
        let actual:IslandSleepTrajectoryEndpoint
        do throws(IslandSleepFailure) { actual=try sleep.query(from:source.accepted,configuration:configuration,to:time,work:&work.islands,cancellation:nil) } catch { throw .sleep(error) }
        try check(cancellation)
        guard actual.source == source.accepted.checkpoint,actual.physical.time.bitPattern == time.bitPattern,actual.accepted.checkpoint.random == source.accepted.checkpoint.random else { throw .hybrid(.invalidContinuation) }
        return actual
    }
}

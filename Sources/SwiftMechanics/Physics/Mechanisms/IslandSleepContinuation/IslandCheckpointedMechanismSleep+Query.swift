@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension IslandCheckpointedMechanismSleep {
    @inline(never)
    public func query(from source:RuntimeAcceptedState,configuration:RuntimeConfiguration,to time:Double,work:inout IslandSleepWork,cancellation:RuntimeCancellationSource? = nil) throws(IslandSleepFailure) -> IslandSleepTrajectoryEndpoint {
        let execution=IslandSleepExecution(work:work,maximum:operationPolicy.maximumSupplierInvocations)
        do throws(RuntimeFailure) {
            try cancellation?.check();try check()
            guard work.queries < operationPolicy.maximumQueries,time.isFinite,time >= source.checkpoint.physical.time,time <= program.constraints.maximumTime,configuration.requiredContributors == schemas.sorted(by:{$0.id < $1.id}) else { throw RuntimeFailure(.capacityExceeded,message:"Isolated mixed trajectory query exceeds caller bounds/full registry.") }
            _=try stepAdapter(source:source,execution:execution)
        } catch { work=execution.read();throw IslandSleepFailure(.runtime(error),accepted:source,work:work) }
        var admitted=execution.read();admitted.queries += 1
        let queryExecution=IslandSleepExecution(work:admitted,maximum:operationPolicy.maximumSupplierInvocations)
        do throws(IslandSleepFailure) {
            let result=try runQuery(source:source,configuration:configuration,to:time,execution:queryExecution,cancellation:cancellation)
            work=queryExecution.read();return result
        } catch { work=queryExecution.read();throw error }
    }
    @inline(never)
    private func runQuery(source:RuntimeAcceptedState,configuration:RuntimeConfiguration,to time:Double,execution:IslandSleepExecution,cancellation:RuntimeCancellationSource?) throws(IslandSleepFailure) -> IslandSleepTrajectoryEndpoint {
        let privateSession:RuntimeSession<IslandSleepCheckpointHandler<ReferenceModelRevisionUpdater>>
        do throws(RuntimeFailure) { privateSession=try bootstrapQuery(source:source,configuration:configuration,execution:execution) }
        catch { throw IslandSleepFailure(.runtime(error),accepted:source,work:execution.read()) }
        defer { _=privateSession.shutdown() }
        var steps=0
        while privateSession.snapshot().checkpoint.physical.time < time {
            do throws(RuntimeFailure) {
                try cancellation?.check();try check();guard steps < operationPolicy.maximumQuerySteps else { throw RuntimeFailure(.capacityExceeded,message:"Mixed private accepted-step capacity exhausted.") }
            } catch { throw IslandSleepFailure(.runtime(error),accepted:source,work:execution.read()) }
            let actual=privateSession.snapshot(),adapter:IslandSleepMechanismEquation
            do throws(RuntimeFailure) {
                let original=try stepAdapter(source:actual,execution:execution)
                adapter=IslandSleepMechanismEquation(owner:self,source:actual,history:original.history,execution:execution,currentSession:privateSession,queryInitialSequence:source.checkpoint.acceptedSteps)
            }
            catch { throw IslandSleepFailure(.runtime(error),accepted:source,work:execution.read()) }
            let next:Double
            do throws(RuntimeFailure) {
                guard let record=actual.checkpoint.contributors.first(where:{$0.id == continuation.schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Private integration history missing.") }
                let proposal=try continuation.history(record).nextStep
                next=min(time,actual.checkpoint.physical.time+proposal)
                guard next > actual.checkpoint.physical.time else { throw RuntimeFailure(.invalidState,message:"Private mixed time cannot advance representably.") }
            } catch { throw IslandSleepFailure(.runtime(error),accepted:source,work:execution.read()) }
            steps += try queryStep(privateSession,adapter:adapter,to:next,source:source,execution:execution)
        }
        let endpoint=privateSession.snapshot()
        guard endpoint.checkpoint.random == source.checkpoint.random else { throw IslandSleepFailure(.runtime(RuntimeFailure(.invalidContributor,message:"Pure mixed trajectory changed original RNG.")),accepted:source,work:execution.read()) }
        return IslandSleepTrajectoryEndpoint(owner:self,source:source.checkpoint,accepted:endpoint,steps:steps)
    }
    @inline(never)
    private func queryStep(_ session:any RuntimeSessionOperating,adapter:IslandSleepMechanismEquation,to time:Double,source:RuntimeAcceptedState,execution:IslandSleepExecution) throws(IslandSleepFailure) -> Int {
        do throws(IntegrationFailure) { return try ReferenceExplicitIntegrator().advance(session,model:model,equations:adapter,continuation:continuation,to:time).acceptedSteps }
        catch { throw IslandSleepFailure(.integration(error),accepted:source,work:execution.read(),supplierFailure:execution.failure()) }
    }
    @inline(never)
    private func bootstrapQuery(source:RuntimeAcceptedState,configuration:RuntimeConfiguration,execution:IslandSleepExecution) throws(RuntimeFailure) -> RuntimeSession<IslandSleepCheckpointHandler<ReferenceModelRevisionUpdater>> {
        let handler=IslandSleepCheckpointHandler(sleep:self,revisions:ReferenceModelRevisionUpdater())
        _=try handler.admit(source.checkpoint,model:model,configuration:configuration,cancellation:nil)
        var records=[try initialRecord(physical:source.checkpoint.physical),try initialIntegrationRecord(physical:source.checkpoint.physical)]
        if let participant {
            let record=try execution.encode { (work:inout NumericalWork) throws(RuntimeFailure) in
                try participant.recordEndpoint(source:source.checkpoint,physical:source.checkpoint.physical,acceptedSequence:0,work:&work)
            };records.append(record)
        }
        let session=try RuntimeSession(model:model,configuration:configuration,initialState:source.checkpoint.physical,contributors:records,seed:source.checkpoint.random.seed,checkpoints:handler)
        do throws(RuntimeFailure) {
            let codec=NativeRuntimeCheckpointCodec(),bytes=try codec.encode(source.checkpoint,capacity:configuration.capacity)
            let restored=try session.restart(bytes,codec:codec)
            guard restored.checkpoint == source.checkpoint else { throw RuntimeFailure(.invalidContributor,message:"Private restart altered full original source.") };return session
        } catch { _=session.shutdown();throw error }
    }
}

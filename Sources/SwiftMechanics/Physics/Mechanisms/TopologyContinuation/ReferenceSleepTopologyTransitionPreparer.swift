@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct ReferenceSleepTopologyTransitionPreparer: SleepTopologyTransitionPreparing {
    public init() {}
    @inline(never)
    public func prepare(source:RuntimeAcceptedState,sourceConfiguration:RuntimeConfiguration,retirement:PreparedSleepTopologyRetirement,
        transition:NonlinearReconciledSubtreeRelease,history:TopologyHistoryContributor,observation:TopologyReleaseObservation,
        ruleID:UInt64,dispositions:[SleepTopologyContributorDisposition],targetConfiguration:RuntimeConfiguration,
        equations:NonlinearMechanismEquation,continuation:IntegrationContinuationProvider,validationBudget:NumericalBudget,
        cancellation:RuntimeCancellationSource?,work:inout NumericalWork) throws(TopologyReleaseFailure) -> PreparedSleepTopologyPublication {
        try poll(cancellation)
        try checkSource(source,configuration:sourceConfiguration,retirement:retirement,transition:transition,history:history,
            observation:observation,target:targetConfiguration,dispositions:dispositions,work:&work)
        try SleepTopologyTargetLaw.validate(retirement,transition:transition,equations:equations,work:&work)
        let candidate=try assemble(source:source,sourceConfiguration:sourceConfiguration,retirement:retirement,
            transition:transition,history:history,observation:observation,ruleID:ruleID,dispositions:dispositions,
            configuration:targetConfiguration,equations:equations,continuation:continuation,validationBudget:validationBudget,work:&work)
        try admit(candidate,cancellation:cancellation,work:&work)
        try poll(cancellation)
        return PreparedSleepTopologyPublication(admission:_SleepTopologyPublicationAdmission(candidate:candidate))
    }
    @inline(never)
    private func checkSource(_ source:RuntimeAcceptedState,configuration:RuntimeConfiguration,retirement:PreparedSleepTopologyRetirement,
        transition:NonlinearReconciledSubtreeRelease,history:TopologyHistoryContributor,observation:TopologyReleaseObservation,
        target:RuntimeConfiguration,dispositions:[SleepTopologyContributorDisposition],work:inout NumericalWork) throws(TopologyReleaseFailure) {
        guard source == retirement.source,retirement.release === transition.release,observation.release === transition.release,
              source.physical == transition.release.source,source.checkpoint.physical == transition.release.source.state,
              configuration.capacity == target.capacity,configuration.continuation == target.continuation,
              configuration.determinism == target.determinism,source.checkpoint.continuation == configuration.continuation,
              source.checkpoint.acceptedSteps < UInt64.max,source.checkpoint.contributors.count == configuration.requiredContributors.count,
              dispositions.count == source.checkpoint.contributors.count,dispositions.count <= target.capacity.maximumContributors else { throw .staleSource }
        try TopologyArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(try NumericalWork.product(128,target.capacity.maximumContributors)) }
        try TopologyArithmetic.charge(history.record.bytes.count,&work)
        do throws(RuntimeFailure) { try history.associated(source.checkpoint) } catch { throw .runtime(error.retaining(source)) }
        guard source.checkpoint.contributors.contains(history.record),history.model.descriptor == transition.release.sourceModel.descriptor else { throw .staleSource }
        for (record,schema) in zip(source.checkpoint.contributors,configuration.requiredContributors) {
            try TopologyArithmetic.charge(1,&work)
            guard record.id == schema.id,record.category == schema.category,record.version == schema.version,record.bytes.count <= schema.maximumBytes else { throw .staleSource }
        }
    }
    @inline(never)
    private func assemble(source:RuntimeAcceptedState,sourceConfiguration:RuntimeConfiguration,retirement:PreparedSleepTopologyRetirement,
        transition:NonlinearReconciledSubtreeRelease,history:TopologyHistoryContributor,observation:TopologyReleaseObservation,
        ruleID:UInt64,dispositions:[SleepTopologyContributorDisposition],configuration:RuntimeConfiguration,
        equations:NonlinearMechanismEquation,continuation:IntegrationContinuationProvider,validationBudget:NumericalBudget,
        work:inout NumericalWork) throws(TopologyReleaseFailure) -> SleepTopologyPublicationCandidate {
        try TopologyArithmetic.charge(history.record.bytes.count,&work)
        let next=try history.appending(source:source,target:transition,observation:observation,ruleID:ruleID)
        let wake=try SleepTopologyWakeContributor(retirement:retirement,transition:transition,history:next,ruleID:ruleID,policy:history.policy,work:&work)
        let catalog=try SleepTopologyCatalogAssembly(source:source,retirement:retirement,transition:transition,history:next,wake:wake,
            dispositions:dispositions,equations:equations,continuation:continuation,configuration:configuration,work:&work)
        let handler=TopologyCheckpointHandler(history:next,contributors:catalog.registry)
        let checkpoints:SleepTopologyCheckpointHandler,checkpoint:RuntimeCheckpoint
        do throws(RuntimeFailure) {
            checkpoints=try SleepTopologyCheckpointHandler(wake:wake,history:next,equations:equations,continuation:continuation,base:handler,validationBudget:validationBudget)
            checkpoint=try RuntimeCheckpoint(model:transition.release.target.stamp,continuation:configuration.continuation,
                physical:transition.physical,contributors:catalog.records,random:source.checkpoint.random,acceptedSteps:source.checkpoint.acceptedSteps+1)
        } catch { throw .runtime(error.retaining(source)) }
        return SleepTopologyPublicationCandidate(source:source,sourceConfiguration:sourceConfiguration,retirement:retirement,
            transition:transition,configuration:configuration,wake:wake,continuation:continuation,handler:handler,checkpoints:checkpoints,checkpoint:checkpoint)
    }
    @inline(never)
    private func admit(_ candidate:SleepTopologyPublicationCandidate,cancellation:RuntimeCancellationSource?,
                       work:inout NumericalWork) throws(TopologyReleaseFailure) {
        try TopologyArithmetic.charge(1,&work)
        do throws(RuntimeFailure) {
            let accepted=try candidate.checkpoints.admit(candidate.checkpoint,model:candidate.transition.release.target,
                configuration:candidate.configuration,cancellation:cancellation)
            guard accepted.checkpoint == candidate.checkpoint,SleepTopologyTargetLaw.same(accepted.physical.state,candidate.transition.physical) else {
                throw RuntimeFailure(.invalidOwnerAccess,message:"Original target admission changed the prepared physical/global-history prefix.")
            }
        } catch { throw .runtime(error.retaining(candidate.source)) }
    }
    @inline(never)
    public func publish(_ prepared:PreparedSleepTopologyPublication,session:any RuntimeModelReplacing) throws(TopologyReleaseFailure) -> RuntimeAcceptedState {
        guard !Task.isCancelled else { throw .cancelled }
        guard session.snapshot() == prepared.source else { throw .staleSource }
        let request=RuntimeModelReplacement(expectedSource:prepared.source.checkpoint,model:prepared.transition.release.target,
            physical:prepared.transition.physical,contributors:prepared.contributors,configuration:prepared.configuration,checkpoints:prepared.checkpoints)
        do throws(RuntimeFailure) { return try session.replaceModel(request) } catch { throw .runtime(error) }
    }
    private func poll(_ cancellation:RuntimeCancellationSource?) throws(TopologyReleaseFailure) {
        do throws(RuntimeFailure) { if let cancellation { try cancellation.check() } } catch { throw .runtime(error) }
        guard !Task.isCancelled else { throw .cancelled }
    }
}

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct _SleepTopologyPublicationAdmission: Sendable {
    let candidate:SleepTopologyPublicationCandidate
    fileprivate init(candidate:SleepTopologyPublicationCandidate) { self.candidate=candidate }
}

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class SleepTopologyAdmissionContext: Sendable {
    let wake:SleepTopologyWakeContributor
    let history:TopologyHistoryContributor
    let physical:NonlinearMechanismCheckpointHandler
    let bootstrapWake:SleepTopologyWakeContributor?
    let bootstrapHistory:TopologyHistoryContributor?
    let bootstrapPhysical:CompiledKinematicState?
    init(wake:SleepTopologyWakeContributor,history:TopologyHistoryContributor,equations:NonlinearMechanismEquation,
         continuation:IntegrationContinuationProvider,base:TopologyCheckpointHandler,validationBudget:NumericalBudget,
         bootstrapWake:SleepTopologyWakeContributor?,bootstrapHistory:TopologyHistoryContributor?,bootstrapPhysical:CompiledKinematicState?) throws(RuntimeFailure) {
        guard base.usesOriginalCatalogAdmission,!wake.isBootstrap,history.record == base.history.record,history.events.last == wake.event,
              history.model.descriptor == equations.model.descriptor,wake.transition.descriptor == equations.descriptor,
              base.contributors.schemas.contains(wake.schema),base.contributors.schemas.contains(continuation.schema) else {
            throw RuntimeFailure(.invalidContributor,message:"Topology wake physical/history/catalog owner differs.")
        }
        // The public cold handler independently enforces the original mapped-law authority.
        // Constructing a wake catalog from a different valid lower token cannot waive it.
        try Self.validateLaw(wake,equations:equations,budget:validationBudget)
        if let bootstrapWake,let bootstrapHistory,let bootstrapPhysical {
            guard bootstrapWake.isBootstrap,bootstrapWake.schema == wake.schema,bootstrapWake.retirement === wake.retirement,
                  bootstrapWake.transition === wake.transition,bootstrapHistory.events.isEmpty,
                  bootstrapHistory.catalog.initialModel == history.model.stamp,bootstrapHistory.catalog.initialSequence == 0,
                  bootstrapHistory.catalog.initialTime.bitPattern == bootstrapPhysical.state.time.bitPattern,
                  bootstrapPhysical.stamp == history.model.stamp,
                  SleepTopologyTargetLaw.same(bootstrapPhysical.state,wake.transition.physical) else {
                throw RuntimeFailure(.invalidContributor,message:"Topology wake cold bootstrap differs from the explicit physical/catalog owner.")
            }
        } else { guard bootstrapWake == nil,bootstrapHistory == nil,bootstrapPhysical == nil else { throw RuntimeFailure(.invalidInput,message:"Topology bootstrap declaration is incomplete.") } }
        self.wake=wake;self.history=history;self.bootstrapWake=bootstrapWake;self.bootstrapHistory=bootstrapHistory;self.bootstrapPhysical=bootstrapPhysical
        physical=try NonlinearMechanismCheckpointHandler(equations:equations,continuation:continuation,base:base,validationBudget:validationBudget)
    }
    @inline(never)
    private static func validateLaw(_ wake:SleepTopologyWakeContributor,equations:NonlinearMechanismEquation,
                                    budget:NumericalBudget) throws(RuntimeFailure) {
        var work=NumericalWork(budget:budget)
        do throws(TopologyReleaseFailure) {
            try SleepTopologyTargetLaw.validate(wake.retirement,transition:wake.transition,equations:equations,work:&work)
        } catch {
            if case .runtime(let original)=error { throw original }
            throw RuntimeFailure(.invalidContributor,message:"Cold topology target law differs from original sleep retirement.",failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable)
        }
    }
    @inline(never)
    func preflight(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,
                   cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) {
        if let cancellation { try cancellation.check() };guard !Task.isCancelled else { throw RuntimeFailure(.cancelled,message:"Topology wake admission cancelled.") }
        guard checkpoint.contributors.count <= configuration.capacity.maximumContributors,model.descriptor == history.model.descriptor,
              let record=checkpoint.contributors.first(where:{$0.id == wake.schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Topology wake or original target is missing.") }
        if let bootstrapWake,let bootstrapHistory,let bootstrapPhysical,record == bootstrapWake.record {
            guard checkpoint.acceptedSteps == 0,SleepTopologyTargetLaw.same(checkpoint.physical,bootstrapPhysical.state),
                  checkpoint.contributors.contains(bootstrapHistory.record) else { throw RuntimeFailure(.invalidContributor,message:"Topology wake bootstrap cannot advance or change its prefix.") }
        } else {
            guard record == wake.record,checkpoint.contributors.contains(history.record),history.events.last == wake.event,
                  checkpoint.acceptedSteps >= wake.event.acceptedSequence,checkpoint.physical.time >= wake.event.acceptedTime else {
                throw RuntimeFailure(.invalidContributor,message:"Accepted topology wake/history is absent, altered or ahead of physical/global history.")
            }
        }
    }
    @inline(never)
    func admitPhysical(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,
                       cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        try physical.admit(checkpoint,model:model,configuration:configuration,cancellation:cancellation)
    }
}

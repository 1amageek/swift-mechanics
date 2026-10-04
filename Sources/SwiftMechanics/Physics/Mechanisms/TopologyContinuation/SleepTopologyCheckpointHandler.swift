/// Required original quadratic physical proof plus accepted topology wake association.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct SleepTopologyCheckpointHandler: RuntimeCheckpointHandling, Sendable {
    private let context:SleepTopologyAdmissionContext
    public init(wake:SleepTopologyWakeContributor,history:TopologyHistoryContributor,equations:NonlinearMechanismEquation,
                continuation:IntegrationContinuationProvider,base:TopologyCheckpointHandler,validationBudget:NumericalBudget) throws(RuntimeFailure) {
        context=try SleepTopologyAdmissionContext(wake:wake,history:history,equations:equations,continuation:continuation,
            base:base,validationBudget:validationBudget,bootstrapWake:nil,bootstrapHistory:nil,bootstrapPhysical:nil)
    }
    public init(wake:SleepTopologyWakeContributor,history:TopologyHistoryContributor,equations:NonlinearMechanismEquation,
                continuation:IntegrationContinuationProvider,base:TopologyCheckpointHandler,validationBudget:NumericalBudget,
                bootstrapWake:SleepTopologyWakeContributor,bootstrapHistory:TopologyHistoryContributor,
                bootstrapPhysical:CompiledKinematicState) throws(RuntimeFailure) {
        context=try SleepTopologyAdmissionContext(wake:wake,history:history,equations:equations,continuation:continuation,
            base:base,validationBudget:validationBudget,bootstrapWake:bootstrapWake,bootstrapHistory:bootstrapHistory,bootstrapPhysical:bootstrapPhysical)
    }
    @inline(never)
    public func admit(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,
                      cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        try context.preflight(checkpoint,model:model,configuration:configuration,cancellation:cancellation)
        return try context.admitPhysical(checkpoint,model:model,configuration:configuration,cancellation:cancellation)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): A later revision has no original disposition of this accepted wake/source law.
    // A new explicit physical reconciliation and complete event/history publication must qualify before migration succeeds.
    public func migrate(_ checkpoint:RuntimeCheckpoint,from source:CompiledMechanicalModel,to target:CompiledMechanicalModel,
                        using transition:ModelTransition,configuration:RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        throw RuntimeFailure(.incompatibleMigration,message:"Sleep topology checkpoint requires explicit later publication.")
    }
}

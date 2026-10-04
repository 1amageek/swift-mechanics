@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct TopologyCheckpointHandler: RuntimeCheckpointHandling, Sendable {
    public let history:TopologyHistoryContributor
    public let contributors:TopologyRuntimeContributors
    private let bootstrap:TopologyHistoryContributor?
    private let bootstrapPhysical:CompiledKinematicState?
    private let bootstrapContributors:TopologyRuntimeContributors?
    private let sourceBase:(any RuntimeCheckpointHandling)?
    internal var usesOriginalCatalogAdmission:Bool { sourceBase == nil }
    public init(history:TopologyHistoryContributor,contributors:TopologyRuntimeContributors) {
        self.history=history;self.contributors=contributors;bootstrap=nil;bootstrapPhysical=nil;bootstrapContributors=nil;sourceBase=nil
    }
    /// Enriches complete source admission while preserving original topology association.
    public init(history:TopologyHistoryContributor,contributors:TopologyRuntimeContributors,base:any RuntimeCheckpointHandling) {
        self.history=history;self.contributors=contributors;sourceBase=base
        bootstrap=nil;bootstrapPhysical=nil;bootstrapContributors=nil
    }
    /// Creates a restore-only owner for an explicit cold physical state and an exact saved final history.
    public init(history:TopologyHistoryContributor,contributors:TopologyRuntimeContributors,
                bootstrap:TopologyHistoryContributor,physical:CompiledKinematicState,
                bootstrapContributors:TopologyRuntimeContributors) throws(TopologyReleaseFailure) {
        guard bootstrap.events.isEmpty,bootstrap.catalog.initialModel == history.model.stamp,
              bootstrap.catalog.initialSequence == 0,bootstrap.catalog.initialTime == physical.state.time,
              physical.stamp == history.model.stamp,bootstrap.model.descriptor == history.model.descriptor,
              bootstrap.schema == history.schema,bootstrapContributors.schemas == contributors.schemas,
              bootstrapContributors.providers.contains(where: { $0.schemas == bootstrap.schemas }) else { throw .invalidInput }
        let admitted:CompiledKinematicState
        do throws(CompilationFailure) { admitted=try history.model.makeState(physical.state) }
        catch { throw .compilation(error) }
        guard admitted == physical else { throw .invalidInput }
        self.history=history;self.contributors=contributors;self.bootstrap=bootstrap
        bootstrapPhysical=physical;self.bootstrapContributors=bootstrapContributors;sourceBase=nil
    }
    public func admit(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,
                      cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        guard model.stamp == history.model.stamp,model.descriptor == history.model.descriptor,
              configuration.requiredContributors == contributors.schemas else { throw RuntimeFailure(.incompatibleModel,message:"Topology target model/catalog differs from the contextual handler.") }
        let registry:TopologyRuntimeContributors
        if let bootstrap,checkpoint.contributors.contains(bootstrap.record) {
            guard checkpoint.acceptedSteps == 0,checkpoint.physical == bootstrapPhysical?.state,
                  let bootstrapContributors else { throw RuntimeFailure(.invalidContributor,message:"Restore-only bootstrap cannot advance or change its physical prefix.") }
            try bootstrap.associated(checkpoint);registry=bootstrapContributors
        } else {
            do throws(TopologyReleaseFailure) {
                let decoded=try TopologyHistoryContributor(model:model,catalog:history.catalog,policy:history.policy,
                    record:checkpoint.contributors.first(where: { $0.id == history.schema.id }))
                guard decoded.record == history.record,decoded.events == history.events else { throw .staleSource }
            } catch { throw RuntimeFailure(.invalidContributor,message:"Saved topology history failed bounded catalog/target reconstruction.") }
            try history.associated(checkpoint);registry=contributors
        }
        if let sourceBase { return try sourceBase.admit(checkpoint,model:model,configuration:configuration,cancellation:cancellation) }
        let handler=ReferenceRuntimeCheckpointHandler(contributors:registry,revisions:ReferenceModelRevisionUpdater())
        return try handler.admit(checkpoint,model:model,configuration:configuration,cancellation:cancellation)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Record-only revision migration cannot reconcile physical acceleration or supplier catalogs.
    // Only an opaque prepared topology publication qualifies a subtree release.
    public func migrate(_ checkpoint:RuntimeCheckpoint,from source:CompiledMechanicalModel,to target:CompiledMechanicalModel,
                        using transition:ModelTransition,configuration:RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        throw RuntimeFailure(.incompatibleMigration,message:"Topology handler requires explicit reconciled publication.")
    }
}

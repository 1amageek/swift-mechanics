@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct GranularRuntimeCheckpointHandler<Revisions: ModelRevisionUpdating>: RuntimeCheckpointHandling, Sendable {
    public let journal: GranularRuntimeJournal
    public let revisions: Revisions
    public init(journal: GranularRuntimeJournal,revisions: Revisions) { self.journal=journal;self.revisions=revisions }
    @inline(never)
    public func admit(_ checkpoint: RuntimeCheckpoint,model: CompiledMechanicalModel,
                      configuration: RuntimeConfiguration,cancellation: RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        guard configuration.requiredContributors.count == 1 else { throw RuntimeFailure(.missingContributor,contributor:journal.schema.id,message:"Granular checkpoint requires exactly its declared journal contributor.") }
        let provider=GranularRuntimeContributors(journal:journal,checkpoint:checkpoint,cancellation:cancellation)
        return try ReferenceRuntimeCheckpointHandler(contributors:provider,revisions:revisions).admit(checkpoint,model:model,configuration:configuration,cancellation:cancellation)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Runtime replacement calls this requirement. Changed source/model/constitutive migration needs explicit original physical conservation; same-source bounded replay does not establish that capability.
    public func migrate(_ checkpoint: RuntimeCheckpoint,from source: CompiledMechanicalModel,to target: CompiledMechanicalModel,
                        using transition: ModelTransition,configuration: RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        throw RuntimeFailure(.unsupportedDomain,contributor:journal.schema.id,message:"Granular Runtime migration is outside unchanged-source journal continuation.")
    }
}

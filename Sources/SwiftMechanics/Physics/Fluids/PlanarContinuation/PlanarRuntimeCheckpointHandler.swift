
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct PlanarRuntimeCheckpointHandler<Revisions: ModelRevisionUpdating>: RuntimeCheckpointHandling, Sendable {
    public let codec: any PlanarContinuationCoding
    public let revisions: Revisions
    public init(codec: any PlanarContinuationCoding, revisions: Revisions) { self.codec = codec; self.revisions = revisions }
    @inline(never)
    public func admit(_ checkpoint: RuntimeCheckpoint, model: CompiledMechanicalModel,
                      configuration: RuntimeConfiguration, cancellation: RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        guard configuration.requiredContributors.count == 1 else {
            throw RuntimeFailure(.missingContributor, contributor: codec.schema.id, message: "Planar continuation requires exactly its one fluid contributor.")
        }
        let provider = PlanarRuntimeContributors(codec: codec, time: checkpoint.physical.time, sequence: checkpoint.acceptedSteps)
        let actual = ReferenceRuntimeCheckpointHandler(contributors: provider, revisions: revisions)
        return try actual.admit(checkpoint, model: model, configuration: configuration, cancellation: cancellation)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Runtime revision replacement calls this requirement; grid/model migration is not implemented. A changed-context checkpoint requires explicit field reconciliation and new physical oracles before success.
    public func migrate(_ checkpoint: RuntimeCheckpoint, from source: CompiledMechanicalModel, to target: CompiledMechanicalModel,
                        using transition: ModelTransition, configuration: RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        throw RuntimeFailure(.unsupportedDomain, contributor: codec.schema.id, message: "Planar checkpoint migration requires an explicit new admission domain.")
    }
}

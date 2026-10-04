@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct SleepRuntimeCheckpointHandler<Revisions:ModelRevisionUpdating>: RuntimeCheckpointHandling, Sendable {
    public let sleep:CheckpointedMechanismSleep
    public let revisions:Revisions
    public init(sleep:CheckpointedMechanismSleep,revisions:Revisions) { self.sleep=sleep;self.revisions=revisions }
    public func admit(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,
                      cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        guard configuration.requiredContributors.count == sleep.schemas.count,
              configuration.requiredContributors.sorted(by:{$0.id < $1.id}) == sleep.schemas.sorted(by:{$0.id < $1.id}) else {
            throw RuntimeFailure(.missingContributor,message:"Sleep runtime requires exactly its sleep and integration contributors.")
        }
        let provider=SleepRuntimeContributors(owner:sleep,physical:checkpoint.physical,sequence:checkpoint.acceptedSteps)
        return try ReferenceRuntimeCheckpointHandler(contributors:provider,revisions:revisions).admit(checkpoint,model:model,
            configuration:configuration,cancellation:cancellation)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Runtime model replacement invokes this topology migration owner. It requires a target force/chart certificate and connected sleep/wake event migration before a new model can be accepted; current static-affine sleep cannot silently reuse old authority.
    public func migrate(_ checkpoint:RuntimeCheckpoint,from source:CompiledMechanicalModel,to target:CompiledMechanicalModel,
                        using transition:ModelTransition,configuration:RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        throw RuntimeFailure(.incompatibleMigration,message:"Sleep topology wake/migration has no target equation authority.")
    }
}

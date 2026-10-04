/// Full source admission with operation-local physical and global-history association.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct SleepTopologySourceCheckpointHandler<Revisions:ModelRevisionUpdating>: RuntimeCheckpointHandling, Sendable {
    public let sleep:CheckpointedMechanismSleep
    public let additional:any RuntimeContributorHandling
    public let revisions:Revisions
    public init(sleep:CheckpointedMechanismSleep,additional:any RuntimeContributorHandling,revisions:Revisions) {
        self.sleep=sleep;self.additional=additional;self.revisions=revisions
    }
    @inline(never)
    public func admit(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,
                      cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        if let cancellation { try cancellation.check() }
        let provider=try SleepTopologyRuntimeContributors(owner:sleep,additional:additional,
            physical:checkpoint.physical,sequence:checkpoint.acceptedSteps,capacity:configuration.capacity)
        guard configuration.requiredContributors == provider.schemas else {
            throw RuntimeFailure(.missingContributor,message:"Complete sleep source schemas differ from the declared registry.")
        }
        return try ReferenceRuntimeCheckpointHandler(contributors:provider,revisions:revisions).admit(checkpoint,
            model:model,configuration:configuration,cancellation:cancellation)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Generic migration does not retire original sleep/law or issue constrained target authority.
    // The explicit retirement and accepted topology publication path must be used before a new revision may succeed.
    public func migrate(_ checkpoint:RuntimeCheckpoint,from source:CompiledMechanicalModel,to target:CompiledMechanicalModel,
                        using transition:ModelTransition,configuration:RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        throw RuntimeFailure(.incompatibleMigration,message:"Sleep topology source requires explicit retirement.")
    }
}

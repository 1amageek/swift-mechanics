@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct IslandSleepCheckpointHandler<Revisions:ModelRevisionUpdating>: IslandSleepCheckpointAdmitting,Sendable {
    public let sleep:IslandCheckpointedMechanismSleep
    public let revisions:Revisions
    public init(sleep:IslandCheckpointedMechanismSleep,revisions:Revisions) { self.sleep=sleep;self.revisions=revisions }
    public func admit(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        do throws(IslandSleepAdmissionFailure) { return try admitWithReport(checkpoint,model:model,configuration:configuration,cancellation:cancellation).accepted }
        catch { throw error.cause }
    }
    @inline(never)
    public func admitWithReport(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,cancellation:RuntimeCancellationSource? = nil) throws(IslandSleepAdmissionFailure) -> IslandSleepAdmissionResult {
        let receipt=IslandSleepAdmissionReceipt()
        do throws(RuntimeFailure) {
            guard sleep.sameModel(model),configuration.requiredContributors == sleep.schemas.sorted(by:{$0.id < $1.id}) else { throw RuntimeFailure(.missingContributor,message:"Mixed checkpoint requires exact actual model/full schema registry.") }
            let provider=IslandSleepRuntimeContributors(owner:sleep,checkpoint:checkpoint,receipt:receipt,cancellation:cancellation)
            let accepted=try ReferenceRuntimeCheckpointHandler(contributors:provider,revisions:revisions).admit(checkpoint,model:model,configuration:configuration,cancellation:cancellation)
            guard let work=receipt.read() else { throw RuntimeFailure(.invalidContributor,message:"Contextual mixed physical validation did not execute.") }
            return IslandSleepAdmissionResult(accepted:accepted,work:work)
        } catch { throw IslandSleepAdmissionFailure(cause:error,work:receipt.read()) }
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Generic model replacement lacks mapped island/law, rest and target integration authority. A genuine accepted topology owner is required before this operation may publish.
    public func migrate(_ checkpoint:RuntimeCheckpoint,from source:CompiledMechanicalModel,to target:CompiledMechanicalModel,using transition:ModelTransition,configuration:RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint { throw RuntimeFailure(.incompatibleMigration,message:"Mixed sleep generic migration is unsupported.") }
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct LoadedSleepRuntimeCheckpointHandler<Revisions:ModelRevisionUpdating>:LoadedSleepCheckpointAdmitting,Sendable {
    public let sleep:LoadedCheckpointedMechanismSleep
    public let revisions:Revisions
    public init(sleep:LoadedCheckpointedMechanismSleep,revisions:Revisions) { self.sleep=sleep;self.revisions=revisions }
    public func admit(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        do throws(LoadedSleepAdmissionFailure) { return try admitWithLoadReport(checkpoint,model:model,configuration:configuration,cancellation:cancellation).accepted }
        catch { throw error.cause }
    }
    public func admitWithLoadReport(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,cancellation:RuntimeCancellationSource? = nil) throws(LoadedSleepAdmissionFailure) -> LoadedSleepAdmissionResult {
        let receipt=LoadedSleepValidationReceipt()
        do throws(RuntimeFailure) {
            guard configuration.requiredContributors.sorted(by:{$0.id < $1.id}) == sleep.schemas.sorted(by:{$0.id < $1.id}) else { throw RuntimeFailure(.missingContributor,message:"Loaded runtime requires exactly loaded sleep/integration schemas.") }
            let provider=LoadedSleepRuntimeContributors(owner:sleep,physical:checkpoint.physical,sequence:checkpoint.acceptedSteps,receipt:receipt,cancellation:cancellation)
            let accepted=try ReferenceRuntimeCheckpointHandler(contributors:provider,revisions:revisions).admit(checkpoint,model:model,configuration:configuration,cancellation:cancellation)
            return LoadedSleepAdmissionResult(accepted:accepted,loads:receipt.read())
        } catch { throw LoadedSleepAdmissionFailure(cause:error,loads:receipt.read()) }
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Runtime topology replacement reaches this public operation. Catalog target binding, physical load migration and connected wake/event mapping require separate actual target proof before publication.
    public func migrate(_ checkpoint:RuntimeCheckpoint,from source:CompiledMechanicalModel,to target:CompiledMechanicalModel,using transition:ModelTransition,configuration:RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        throw RuntimeFailure(.incompatibleMigration,message:"Loaded catalog/topology migration authority is unavailable.")
    }
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol LoadedSleepCheckpointAdmitting:RuntimeCheckpointHandling {
    func admitWithLoadReport(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,cancellation:RuntimeCancellationSource?) throws(LoadedSleepAdmissionFailure) -> LoadedSleepAdmissionResult
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol IslandSleepCheckpointAdmitting: RuntimeCheckpointHandling {
    func admitWithReport(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,cancellation:RuntimeCancellationSource?) throws(IslandSleepAdmissionFailure) -> IslandSleepAdmissionResult
}

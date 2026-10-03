import MechanicsCompiler

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol RuntimeCheckpointHandling: Sendable {
    func admit(_ checkpoint: RuntimeCheckpoint, model: CompiledMechanicalModel,
               configuration: RuntimeConfiguration, cancellation: RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState
    func migrate(_ checkpoint: RuntimeCheckpoint, from source: CompiledMechanicalModel, to target: CompiledMechanicalModel,
                 using transition: ModelTransition, configuration: RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint
}

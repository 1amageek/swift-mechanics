import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class RuntimeReplacementHandler: RuntimeCheckpointHandling, Sendable {
    let base: RuntimeFixtures.Handler
    let onAdmission: (@Sendable () throws(RuntimeFailure) -> Void)?
    let onRetire: (@Sendable () -> Void)?
    init(onAdmission: (@Sendable () throws(RuntimeFailure) -> Void)? = nil, onRetire: (@Sendable () -> Void)? = nil) throws {
        base = try RuntimeFixtures.handler(); self.onAdmission = onAdmission; self.onRetire = onRetire
    }
    deinit { onRetire?() }
    func admit(_ checkpoint: RuntimeCheckpoint, model: CompiledMechanicalModel, configuration: RuntimeConfiguration,
               cancellation: RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        try onAdmission?()
        return try base.admit(checkpoint, model: model, configuration: configuration, cancellation: cancellation)
    }
    func migrate(_ checkpoint: RuntimeCheckpoint, from source: CompiledMechanicalModel, to target: CompiledMechanicalModel,
                 using transition: ModelTransition, configuration: RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        try base.migrate(checkpoint, from: source, to: target, using: transition, configuration: configuration)
    }
}

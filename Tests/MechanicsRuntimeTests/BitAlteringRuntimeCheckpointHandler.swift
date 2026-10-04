import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct BitAlteringRuntimeCheckpointHandler: RuntimeCheckpointHandling {
    let lower: RuntimeFixtures.Handler
    let quaternion: Bool
    func admit(_ checkpoint: RuntimeCheckpoint, model: CompiledMechanicalModel, configuration: RuntimeConfiguration,
               cancellation: RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        guard checkpoint.acceptedSteps > 0 else { return try lower.admit(checkpoint, model: model, configuration: configuration, cancellation: cancellation) }
        var samples = checkpoint.physical.prescribedAnchors
        guard let index = samples.firstIndex(where: { $0.frame.key == "moving-parent" }) else { throw RuntimeFailure(.invalidState, message: "Fixture source frame missing.") }
        samples[index] = try RuntimeMovingAnchorFixtures.altered(samples[index], quaternion: quaternion)
        let changed: RuntimeCheckpoint
        do { changed = try RuntimeMovingAnchorFixtures.checkpoint(checkpoint, anchors: samples) }
        catch { throw RuntimeFailure(.invalidState, message: "Fixture checkpoint construction failed.") }
        // The actual lower handler validates the altered complete state and issues its genuine sealed token.
        return try lower.admit(changed, model: model, configuration: configuration, cancellation: cancellation)
    }
    func migrate(_ checkpoint: RuntimeCheckpoint, from source: CompiledMechanicalModel, to target: CompiledMechanicalModel,
                 using transition: ModelTransition, configuration: RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        try lower.migrate(checkpoint, from: source, to: target, using: transition, configuration: configuration)
    }
}

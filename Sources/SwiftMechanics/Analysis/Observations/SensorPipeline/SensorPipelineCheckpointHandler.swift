@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct SensorPipelineCheckpointHandler<Base: RuntimeCheckpointHandling>: RuntimeCheckpointHandling {
    public let base: Base
    public let definition: SensorPipelineDefinition
    private let engine: SensorPipelineEngine
    public init(base: Base, definition: SensorPipelineDefinition, capacity: RuntimeCapacity) {
        self.base = base; self.definition = definition; engine = SensorPipelineEngine(definition: definition, capacity: capacity)
    }
    @inline(never)
    public func admit(_ checkpoint: RuntimeCheckpoint, model: CompiledMechanicalModel, configuration: RuntimeConfiguration,
                      cancellation: RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        do throws(SensorPipelineFailure) {
            guard configuration.capacity == engine.capacity,
                  configuration.requiredContributors.contains(definition.schema),
                  let record = checkpoint.contributors.first(where: { $0.id == definition.schemaID }) else { throw .incompatibleSchema }
            let budget: RuntimeValidationBudget
            do { budget = try RuntimeValidationBudget(workUnits: configuration.capacity.maximumValidationWork / 2,
                scratchBytes: configuration.capacity.maximumValidationScratchBytes) }
            catch { throw .runtime(error) }
            let state = try engine.decode(record, model: model, budget: budget).state
            guard state.source.acceptedSequence == checkpoint.acceptedSteps,
                  state.source.encoded == (try engine.binding(model: model, physical: checkpoint.physical, sequence: checkpoint.acceptedSteps)).encoded else { throw .staleSource }
            do { try cancellation?.check() } catch { throw .runtime(error) }
        } catch {
            let failure = error.runtimeFailure
            throw RuntimeFailure(failure.code, contributor: definition.schemaID, message: failure.message,
                failedSupplierWorkUnavailable: failure.failedSupplierWorkUnavailable)
        }
        // The base must know the complete union. Never strip the observation contributor.
        return try base.admit(checkpoint, model: model, configuration: configuration, cancellation: cancellation)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): A model revision cannot carry sensor history without explicit schema/source migration.
    // This public requirement refuses; actual mapped contributor/physical replay behavior is required before success.
    public func migrate(_ checkpoint: RuntimeCheckpoint, from source: CompiledMechanicalModel, to target: CompiledMechanicalModel,
                        using transition: ModelTransition, configuration: RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        throw RuntimeFailure(.unsupportedDomain, contributor: definition.schemaID, message: "Sensor checkpoint migration is unsupported.")
    }
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct SensorPipelineContributorHandler<Original: RuntimeContributorHandling>: RuntimeContributorHandling {
    public let original: Original
    public let definition: SensorPipelineDefinition
    private let engine: SensorPipelineEngine
    public init(original: Original, definition: SensorPipelineDefinition, capacity: RuntimeCapacity) throws(SensorPipelineFailure) {
        guard !original.schemas.contains(where: { $0.id == definition.schemaID }),
              original.schemas.count < capacity.maximumContributors,
              definition.bounds.maximumContributorBytes <= capacity.maximumContributorBytes else { throw .invalidDefinition }
        self.original = original; self.definition = definition; engine = SensorPipelineEngine(definition: definition, capacity: capacity)
    }
    public var schemas: [RuntimeContributorSchema] { original.schemas + [definition.schema] }
    public func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel,
                         budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard record.id == definition.schemaID else { return try original.validate(record, model: model, budget: budget) }
        do throws(SensorPipelineFailure) {
            let limited: RuntimeValidationBudget
            do { limited = try RuntimeValidationBudget(workUnits: budget.workUnits / 2, scratchBytes: budget.scratchBytes) }
            catch { throw .runtime(error) }
            let evidence = try engine.decode(record, model: model, budget: limited).evidence
            // Reserve both this required-record pass and the full physical-association wrapper pass.
            let combined = evidence.workUnitsUsed.multipliedReportingOverflow(by: 2)
            guard !combined.overflow else { throw .capacityExceeded }
            do { return try RuntimeValidationEvidence(workUnitsUsed: combined.partialValue, scratchBytesUsed: evidence.scratchBytesUsed) }
            catch { throw .runtime(error) }
        }
        catch { throw mapped(error) }
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Sensor clock/source/schema migration has no admitted mapping contract.
    // Runtime migration reaches this requirement; explicit migration behavior and replay proof are required before success.
    public func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel,
                        budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        guard record.id != definition.schemaID else { throw RuntimeFailure(.unsupportedDomain, contributor: record.id, message: "Sensor contributor migration is unsupported.") }
        return try original.migrate(record, transition: transition, target: target, budget: budget)
    }
    private func mapped(_ error: SensorPipelineFailure) -> RuntimeFailure {
        let failure = error.runtimeFailure
        return RuntimeFailure(failure.code, contributor: definition.schemaID, message: failure.message,
            failedSupplierWorkUnavailable: failure.failedSupplierWorkUnavailable)
    }
}

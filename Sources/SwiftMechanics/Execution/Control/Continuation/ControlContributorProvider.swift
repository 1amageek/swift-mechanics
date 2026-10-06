@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct ControlContributorProvider: RuntimeContributorHandling, Sendable {
    let actuator:ActuatorRuntimeContributors
    let integration:IntegrationContinuationProvider
    let codec:ControlContinuationCodec
    var schemas:[RuntimeContributorSchema] { actuator.schemas+[integration.schema,codec.schema] }
    func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        if record.id == codec.schema.id {
            guard model.stamp == integration.descriptor.model,record.bytes.count <= budget.workUnits,record.bytes.count <= budget.scratchBytes else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Controller validation capacity exceeded.") }
            _=try codec.history(record)
            return try RuntimeValidationEvidence(workUnitsUsed:record.bytes.count,scratchBytesUsed:record.bytes.count)
        }
        if record.id == integration.schema.id { return try integration.validate(record,model:model,budget:budget) }
        return try actuator.validate(record,model:model,budget:budget)
    }
    func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Control contributor migration reaches this provider.
        // Configuration, period, chart and sample/held-state preservation need a joint certificate before migration can succeed.
        throw RuntimeFailure(.incompatibleMigration,message:"Sampled control migration is not admitted.")
    }
}

import MechanicsCompiler
import MechanicsRuntime
import MechanicsIntegration

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct IntegrationTestContributors: RuntimeContributorHandling {
    let integration: IntegrationContinuationProvider
    var schemas: [RuntimeContributorSchema] { integration.schemas + [counterSchema] }
    private let counterSchema: RuntimeContributorSchema
    init(integration: IntegrationContinuationProvider) throws {
        self.integration = integration
        counterSchema = try RuntimeContributorSchema(id: "actuation-counter", category: .actuator, version: 1, maximumBytes: 1)
    }
    static func counter(_ value: UInt8 = 0) throws -> RuntimeContributorState { try RuntimeContributorState(id: "actuation-counter", category: .actuator, version: 1, bytes: [value]) }
    func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        if record.id == integration.schema.id { return try integration.validate(record,model: model,budget: budget) }
        guard record.id == counterSchema.id, record.category == counterSchema.category, record.version == 1, record.bytes.count == 1,
              budget.workUnits >= 1 else { throw RuntimeFailure(.invalidContributor, message: "Fixture actuation state invalid.") }
        return try RuntimeValidationEvidence(workUnitsUsed: 1,scratchBytesUsed: 0)
    }
    func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.incompatibleMigration, message: "Fixture requires explicit integration reset.")
    }
}

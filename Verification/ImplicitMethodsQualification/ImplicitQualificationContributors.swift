import SwiftMechanics

public struct ImplicitQualificationContributors: RuntimeContributorHandling, Sendable {
    public let schemas: [RuntimeContributorSchema]
    public init(category: RuntimeContributorCategory = .actuator) throws(RuntimeFailure) {
        schemas = [try RuntimeContributorSchema(id: "implicit-physical-preparation", category: category, version: 1, maximumBytes: 1)]
    }
    public func initialRecord() throws(RuntimeFailure) -> RuntimeContributorState {
        try RuntimeContributorState(id: schemas[0].id, category: schemas[0].category, version: 1, bytes: [0])
    }
    public func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel,
                         budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard record.id == schemas[0].id && record.category == schemas[0].category && record.version == 1 && record.bytes.count == 1 else {
            throw RuntimeFailure(.invalidContributor, message: "Declared preparation contributor schema mismatch.")
        }
        guard budget.workUnits >= 1 else { throw RuntimeFailure(.contributorBudgetExceeded, message: "Preparation contributor read budget.") }
        return try RuntimeValidationEvidence(workUnitsUsed: 1, scratchBytesUsed: 0)
    }
    public func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel,
                        budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.incompatibleMigration, message: "This bounded qualification provider declares no revision migration.")
    }
}

import SwiftMechanics

/// The selected complete catalog: original numerical history and exact admitted CAD recipe.
@available(macOS 15, *)
public struct CADGearRuntimeContributors: RuntimeContributorHandling, Sendable {
    public let continuation: IntegrationContinuationProvider
    public let schema: RuntimeContributorSchema
    public let record: RuntimeContributorState
    private let model: CompiledMechanicalModel
    public var schemas: [RuntimeContributorSchema] { [schema, continuation.schema] }
    init(admission: _CADGearCatalogAdmission) {
        continuation = admission.continuation; schema = admission.schema
        record = admission.record; model = admission.model
    }
    public func validate(_ value: RuntimeContributorState, model target: CompiledMechanicalModel,
                         budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard target.stamp == model.stamp, target.descriptor == model.descriptor,
              target.tree.layout == model.tree.layout else {
            throw RuntimeFailure(.incompatibleModel, message: "CAD recipe belongs to another compiled physical source.")
        }
        if value.id == continuation.schema.id { return try continuation.validate(value, model: target, budget: budget) }
        guard value.id == schema.id, value.category == schema.category, value.version == schema.version,
              value.bytes.count <= schema.maximumBytes else {
            throw RuntimeFailure(.invalidContributor, message: "CAD recipe schema or bound differs.")
        }
        guard record.bytes.count <= budget.workUnits else {
            throw RuntimeFailure(.contributorBudgetExceeded, message: "CAD recipe comparison exceeds validation work.")
        }
        guard value == record else {
            throw RuntimeFailure(.invalidContributor, message: "CAD source, occurrence, shaft or physical recipe differs.")
        }
        return try RuntimeValidationEvidence(workUnitsUsed: record.bytes.count, scratchBytesUsed: 0)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): The selected recipe catalog has explicit reinitialization authority only.
    // Runtime record-only migration must not succeed before original CAD/physical/law compatibility is proved.
    public func migrate(_ record: RuntimeContributorState, transition: ModelTransition,
                        target: CompiledMechanicalModel, budget: RuntimeValidationBudget)
        throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.incompatibleMigration, message: "CAD gear continuation requires explicit reinitialization.")
    }
}

import SwiftMechanics

struct CounterRuntimeContributors: RuntimeContributorHandling {
    let schemas: [RuntimeContributorSchema]
    init() throws { schemas = [try RuntimeContributorSchema(id: "integrator-counter", category: .integrator, version: 1, maximumBytes: 8)] }
    static func record(_ count: UInt64) throws(RuntimeFailure) -> RuntimeContributorState {
        var bytes: [UInt8] = []; bytes.reserveCapacity(8)
        for i in 0..<8 { bytes.append(UInt8(truncatingIfNeeded: count >> (8*i))) }
        return try RuntimeContributorState(id: "integrator-counter", category: .integrator, version: 1, bytes: bytes)
    }
    static func count(_ record: RuntimeContributorState) throws(RuntimeFailure) -> UInt64 {
        guard record.bytes.count == 8 else { throw RuntimeFailure(.invalidContributor, contributor: record.id, message: "Counter state requires eight bytes.") }
        var count: UInt64 = 0
        for i in 0..<8 { count |= UInt64(record.bytes[i]) << (i*8) }; return count
    }
    func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard record.id == "integrator-counter", record.category == .integrator, record.version == 1 else { throw RuntimeFailure(.invalidContributor, contributor: record.id, message: "Counter schema is incompatible.") }
        _ = try Self.count(record)
        guard budget.workUnits >= 8 else { throw RuntimeFailure(.contributorBudgetExceeded, contributor: record.id, message: "Counter read work budget exhausted.") }
        return try RuntimeValidationEvidence(workUnitsUsed: 8, scratchBytesUsed: 0)
    }
    func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        guard transition.compatibility == .preservesCoordinates else { throw RuntimeFailure(.incompatibleMigration, contributor: record.id, message: "Counter continuation requires identical kinematics.") }
        _ = try validate(record, model: target, budget: budget)
        return record
    }
}

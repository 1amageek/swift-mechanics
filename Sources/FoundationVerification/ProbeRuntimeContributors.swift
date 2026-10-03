import MechanicsCompiler
import MechanicsRuntime

struct ProbeRuntimeContributors: RuntimeContributorHandling {
    let schemas: [RuntimeContributorSchema]
    init() throws(RuntimeFailure) {
        schemas = [try RuntimeContributorSchema(id: "probe-counter", category: .integrator, version: 1, maximumBytes: 8)]
    }
    static func record(_ value: UInt64) throws(RuntimeFailure) -> RuntimeContributorState {
        var bytes: [UInt8] = []; bytes.reserveCapacity(8)
        for i in 0..<8 { bytes.append(UInt8(truncatingIfNeeded: value >> (8*i))) }
        return try RuntimeContributorState(id: "probe-counter", category: .integrator, version: 1, bytes: bytes)
    }
    static func count(_ record: RuntimeContributorState) throws(RuntimeFailure) -> UInt64 {
        guard record.id == "probe-counter", record.category == .integrator, record.version == 1, record.bytes.count == 8 else {
            throw RuntimeFailure(.invalidContributor, message: "Probe counter schema is incompatible.")
        }
        var value: UInt64 = 0
        for i in 0..<8 { value |= UInt64(record.bytes[i]) << (8*i) }; return value
    }
    func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel,
                  budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard budget.workUnits >= 8 else { throw RuntimeFailure(.contributorBudgetExceeded, message: "Probe counter budget exhausted.") }
        _ = try Self.count(record)
        return try RuntimeValidationEvidence(workUnitsUsed: 8, scratchBytesUsed: 0)
    }
    func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel,
                 budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        guard transition.compatibility == .preservesCoordinates else {
            throw RuntimeFailure(.incompatibleMigration, message: "Probe counter requires unchanged coordinates.")
        }
        _ = try validate(record, model: target, budget: budget); return record
    }
}

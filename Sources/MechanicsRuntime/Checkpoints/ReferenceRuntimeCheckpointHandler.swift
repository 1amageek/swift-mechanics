import MechanicsCompiler
import MechanicsJoints

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferenceRuntimeCheckpointHandler<Contributors: RuntimeContributorHandling, Revisions: ModelRevisionUpdating>: RuntimeCheckpointHandling, Sendable {
    public let contributors: Contributors
    public let revisions: Revisions
    public init(contributors: Contributors, revisions: Revisions) { self.contributors = contributors; self.revisions = revisions }

    public func admit(_ checkpoint: RuntimeCheckpoint, model: CompiledMechanicalModel,
                      configuration: RuntimeConfiguration, cancellation: RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        let cap = configuration.capacity
        // FIXME(INCOMPLETE_IMPLEMENTATION): Stronger determinism requests reach checkpoint/session admission.
        // Exact target-pair numerical/bitwise workload evidence is required before qualifying these tiers.
        guard configuration.determinism == .sameBuildReplay else { throw RuntimeFailure(.unsupportedDeterminism, message: "Only same-build replay is admitted in this transaction domain.") }
        guard checkpoint.model == model.stamp else { throw RuntimeFailure(.incompatibleModel, message: "Checkpoint model identity/revision is incompatible.") }
        guard checkpoint.continuation == configuration.continuation else { throw RuntimeFailure(.incompatibleContinuation, message: "Checkpoint build/backend/precision continuation is incompatible.") }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Moving-anchor derivative checkpoints reach this admission branch.
        // Exact raw rotation/derivative continuation encoding must be implemented and proved before admission.
        guard checkpoint.physical.prescribedAnchors.isEmpty,
              model.tree.joints.allSatisfy({ joint in
                  if case .prescribed = joint.parentAnchor.placement { return false }
                  if case .prescribed = joint.childAnchor.placement { return false }
                  return true
              }) else { throw RuntimeFailure(.unsupportedDomain, message: "Moving-anchor continuation is outside checkpoint v1.") }
        let scalarCount = try RuntimeCounts.physical(q: checkpoint.physical.q.count, v: checkpoint.physical.v.count)
        guard scalarCount <= cap.maximumPhysicalScalars, checkpoint.physical.acceleration.count == checkpoint.physical.v.count,
              checkpoint.contributors.count <= cap.maximumContributors else { throw RuntimeFailure(.capacityExceeded, message: "Checkpoint scalar/contributor capacity exceeded.") }
        let registrations = contributors.schemas
        guard registrations.count <= cap.maximumContributors else { throw RuntimeFailure(.capacityExceeded, message: "Contributor registry exceeds capacity.") }
        var registry: [String: RuntimeContributorSchema] = [:], metadataBytes = checkpoint.model.identity.utf8.count
        guard metadataBytes <= cap.maximumMetadataBytes else { throw RuntimeFailure(.capacityExceeded, message: "Model identity exceeds runtime metadata capacity.") }
        for schema in registrations {
            metadataBytes = try RuntimeCounts.sum(metadataBytes, schema.id.utf8.count)
            guard metadataBytes <= cap.maximumMetadataBytes else { throw RuntimeFailure(.capacityExceeded, message: "Registry metadata exceeds capacity.") }
            guard registry[schema.id] == nil else { throw RuntimeFailure(.duplicateContributor, contributor: schema.id, message: "Provider schema is duplicated.") }
            registry[schema.id] = schema
        }
        var records: [String: RuntimeContributorState] = [:], payloadBytes = 0
        for record in checkpoint.contributors {
            metadataBytes = try RuntimeCounts.sum(metadataBytes, record.id.utf8.count)
            payloadBytes = try RuntimeCounts.sum(payloadBytes, record.bytes.count)
            guard metadataBytes <= cap.maximumMetadataBytes, payloadBytes <= cap.maximumContributorBytes else { throw RuntimeFailure(.capacityExceeded, contributor: record.id, message: "Checkpoint metadata/payload bytes exceed capacity.") }
            guard records[record.id] == nil else { throw RuntimeFailure(.duplicateContributor, contributor: record.id, message: "Contributor state is duplicated.") }
            records[record.id] = record
        }
        let requiredIDs = Set(configuration.requiredContributors.map { $0.id })
        for record in checkpoint.contributors where !requiredIDs.contains(record.id) { throw RuntimeFailure(.unknownContributor, contributor: record.id, message: "Checkpoint has undeclared contributor state.") }
        var used = 0, canonical: [RuntimeContributorState] = []
        canonical.reserveCapacity(configuration.requiredContributors.count)
        for schema in configuration.requiredContributors {
            guard let registration = registry[schema.id], registration.category == schema.category, registration.version == schema.version,
                  schema.maximumBytes <= registration.maximumBytes else { throw RuntimeFailure(.missingContributor, contributor: schema.id, message: "Required contributor validator is missing/incompatible.") }
            guard let record = records[schema.id] else { throw RuntimeFailure(.missingContributor, contributor: schema.id, message: "Required contributor state is missing.") }
            guard record.category == schema.category, record.version == schema.version, record.bytes.count <= schema.maximumBytes else { throw RuntimeFailure(.invalidContributor, contributor: schema.id, message: "Contributor schema/version/byte bound is incompatible.") }
            try cancellation?.check()
            guard !Task.isCancelled else { throw RuntimeFailure(.cancelled, message: "Contributor admission cancelled.") }
            let budget = try RuntimeValidationBudget(workUnits: cap.maximumValidationWork - used, scratchBytes: cap.maximumValidationScratchBytes)
            let evidence = try contributors.validate(record, model: model, budget: budget)
            guard evidence.workUnitsUsed <= budget.workUnits, evidence.scratchBytesUsed <= budget.scratchBytes else { throw RuntimeFailure(.contributorBudgetExceeded, contributor: schema.id, message: "Contributor returned over-budget validation evidence.") }
            used = try RuntimeCounts.sum(used, evidence.workUnitsUsed)
            canonical.append(record)
        }
        try cancellation?.check()
        guard !Task.isCancelled else { throw RuntimeFailure(.cancelled, message: "Physical admission cancelled.") }
        let physical: CompiledKinematicState
        do { physical = try model.makeState(checkpoint.physical) }
        catch { throw RuntimeFailure(.invalidState, message: "Actual compiled-tree state admission failed.") }
        let normalized = try RuntimeCheckpoint(model: checkpoint.model, continuation: checkpoint.continuation, physical: checkpoint.physical,
            contributors: canonical, random: checkpoint.random, acceptedSteps: checkpoint.acceptedSteps)
        return RuntimeAcceptedState(physical: physical, checkpoint: normalized)
    }

    public func migrate(_ checkpoint: RuntimeCheckpoint, from source: CompiledMechanicalModel, to target: CompiledMechanicalModel,
                        using transition: ModelTransition, configuration: RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        let old = try admit(checkpoint, model: source, configuration: configuration, cancellation: nil)
        let physical: CompiledKinematicState
        do { physical = try revisions.migrate(old.physical, using: transition, to: target) }
        catch { throw RuntimeFailure(.incompatibleMigration, message: "Compiler rejected physical-state migration.") }
        var migrated: [RuntimeContributorState] = []
        migrated.reserveCapacity(old.checkpoint.contributors.count)
        // Each migration has the explicit per-record budget; final admission enforces cumulative validation work.
        let budget = try RuntimeValidationBudget(workUnits: configuration.capacity.maximumValidationWork,
            scratchBytes: configuration.capacity.maximumValidationScratchBytes)
        for record in old.checkpoint.contributors {
            guard !Task.isCancelled else { throw RuntimeFailure(.cancelled, message: "Contributor migration cancelled.") }
            let value = try contributors.migrate(record, transition: transition, target: target, budget: budget)
            guard value.id == record.id else { throw RuntimeFailure(.invalidContributor, contributor: record.id, message: "Migration changed contributor identity.") }
            migrated.append(value)
        }
        let result = try RuntimeCheckpoint(model: target.stamp, continuation: checkpoint.continuation, physical: physical.state,
            contributors: migrated, random: checkpoint.random, acceptedSteps: checkpoint.acceptedSteps)
        return try admit(result, model: target, configuration: configuration, cancellation: nil).checkpoint
    }
}

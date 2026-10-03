import MechanicsCompiler
import MechanicsRuntime

public struct HybridContributors<Base: RuntimeContributorHandling>: RuntimeContributorHandling, Sendable {
    public let base: Base
    public let events: HybridContinuationProvider
    public var schemas: [RuntimeContributorSchema] { base.schemas+events.schemas }
    public init(base: Base, events: HybridContinuationProvider) throws(RuntimeFailure) {
        guard !base.schemas.contains(where: { $0.id == events.schema.id }) else { throw RuntimeFailure(.duplicateContributor,message:"Hybrid contributor already registered.") }
        self.base=base; self.events=events
    }
    public func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        if record.id == events.schema.id { return try events.validate(record,model:model,budget:budget) }
        return try base.validate(record,model:model,budget:budget)
    }
    public func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        if record.id == events.schema.id { return try events.migrate(record,transition:transition,target:target,budget:budget) }
        return try base.migrate(record,transition:transition,target:target,budget:budget)
    }
}

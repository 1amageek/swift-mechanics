
public struct NoRuntimeContributors: RuntimeContributorHandling, Sendable {
    public init() {}
    public var schemas: [RuntimeContributorSchema] { [] }
    public func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        throw RuntimeFailure(.unknownContributor, contributor: record.id, message: "Empty provider does not own this contributor.")
    }
    public func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.unknownContributor, contributor: record.id, message: "Empty provider cannot migrate contributor state.")
    }
}

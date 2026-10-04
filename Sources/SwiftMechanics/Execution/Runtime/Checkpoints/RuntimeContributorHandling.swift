
public protocol RuntimeContributorHandling: Sendable {
    var schemas: [RuntimeContributorSchema] { get }
    func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel,
                  budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence
    func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel,
                 budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState
}

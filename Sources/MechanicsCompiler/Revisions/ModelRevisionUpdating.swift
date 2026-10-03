public protocol ModelRevisionUpdating: Sendable {
    func transition(from source: CompiledMechanicalModel, to target: CompiledMechanicalModel,
                    policy: StateMigrationPolicy) throws(CompilationFailure) -> ModelTransition
    func migrate(_ state: CompiledKinematicState, using transition: ModelTransition,
                 to target: CompiledMechanicalModel) throws(CompilationFailure) -> CompiledKinematicState
}

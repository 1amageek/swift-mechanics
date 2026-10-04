public protocol MechanicalModelCompiling: Sendable {
    func compile(_ descriptor: MechanicalDescriptor, policy: CompilationPolicy) throws(CompilationFailure) -> CompiledMechanicalModel
}

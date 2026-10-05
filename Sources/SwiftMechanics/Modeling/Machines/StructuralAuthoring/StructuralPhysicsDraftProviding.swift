public protocol StructuralPhysicsDraftProviding: Sendable {
    func makePhysicsDraft(definitionPolicy: MachineDefinitionPolicy,
                          compilationPolicy: CompilationPolicy) throws(MachineDefinitionFailure) -> StructuralPhysicsDraft
}

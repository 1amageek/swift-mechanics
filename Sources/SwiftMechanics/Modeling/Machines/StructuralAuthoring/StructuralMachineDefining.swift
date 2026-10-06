/// Produces a complete spatial structural draft through the original record contracts.
public protocol StructuralMachineDefining: Sendable {
    func makeDescriptor(definitionPolicy: MachineDefinitionPolicy,
                        compilationPolicy: CompilationPolicy) throws(MachineDefinitionFailure) -> MechanicalDescriptor
}

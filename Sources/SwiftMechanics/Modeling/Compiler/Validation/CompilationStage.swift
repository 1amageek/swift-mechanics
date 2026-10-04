public enum CompilationStage: Equatable, Sendable {
    case input, identities, topology, inertia, modes, coordinates, initialAssembly, representations,
         capabilities, extensionValidation, layout, migration
}

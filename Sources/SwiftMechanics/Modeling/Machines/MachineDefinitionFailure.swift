public enum MachineDefinitionFailure: Error, Equatable, Sendable {
    case invalidPolicy
    case invalidNamespace
    case reservedIdentity(EntityID)
    case duplicateIdentity(EntityID)
    case duplicateInstance(String)
    case capacityExceeded
    case depthExceeded
    case invalidBody(ModelError)
    case invalidJoint(JointError)
    case compilation(CompilationFailure)
}

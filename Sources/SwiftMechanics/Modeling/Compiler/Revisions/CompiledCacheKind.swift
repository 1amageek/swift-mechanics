public enum CompiledCacheKind: Equatable, Hashable, Sendable {
    case bodyKinematics, bodyInertia, geometricRepresentation, displayRepresentation, collisionRepresentation,
         stateLayout, sparsity, capabilityAdmission, extensionValidation
}

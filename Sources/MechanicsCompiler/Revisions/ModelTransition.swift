import MechanicsModel

public struct ModelTransition: Sendable {
    public let source: ModelStamp
    public let target: ModelStamp
    public let kind: ModelChangeKind
    public let changedParameters: [ParameterReference]
    public let invalidatedCaches: [CompiledCacheKey]
    public let policy: StateMigrationPolicy
    public let compatibility: MigrationCompatibility
    internal let targetDescriptor: MechanicalDescriptor
    internal let targetPolicy: CompilationPolicy
    internal let targetRegistrations: [ValidatorRegistration]

    internal init(source: ModelStamp, model: CompiledMechanicalModel, kind: ModelChangeKind,
                  changedParameters: [ParameterReference], invalidatedCaches: [CompiledCacheKey],
                  policy: StateMigrationPolicy, compatibility: MigrationCompatibility) {
        self.source = source; self.target = model.stamp; self.kind = kind
        self.changedParameters = changedParameters; self.invalidatedCaches = invalidatedCaches
        self.policy = policy; self.compatibility = compatibility
        self.targetDescriptor = model.descriptor; self.targetPolicy = model.policy
        self.targetRegistrations = model.validatorRegistrations
    }
}

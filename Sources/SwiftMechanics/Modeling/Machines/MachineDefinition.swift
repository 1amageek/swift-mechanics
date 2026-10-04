public struct MachineDefinition<Content: Machine>: Sendable {
    public let identity: String
    public let revision: UInt64
    public let root: EntityID
    public let rootBase: BaseLayout
    public let rootAuthority: CoordinateAuthority
    public let worldFrame: EntityID
    public let initialState: KinematicState
    public let content: Content

    public init(identity: String, revision: UInt64, root: EntityID, rootBase: BaseLayout,
                rootAuthority: CoordinateAuthority, worldFrame: EntityID, initialState: KinematicState,
                @MachineBuilder content: () -> Content) {
        self.identity = identity; self.revision = revision; self.root = root; self.rootBase = rootBase
        self.rootAuthority = rootAuthority; self.worldFrame = worldFrame; self.initialState = initialState
        self.content = content()
    }

    public func makeDescriptor(policy: MachineDefinitionPolicy) throws(MachineDefinitionFailure) -> MechanicalDescriptor {
        var context = MachineDefinitionContext(policy: policy)
        try context.reserveWorld(worldFrame)
        try context.lower(content)
        do {
            return try MechanicalDescriptor(identity: identity, revision: revision, bodies: context.bodies,
                joints: context.joints, root: root, rootBase: rootBase, rootAuthority: rootAuthority,
                worldFrame: worldFrame, initialState: initialState, representationRequirements: [], features: [], extensions: [])
        } catch { throw .compilation(error) }
    }

    public func compile(definitionPolicy: MachineDefinitionPolicy, compilationPolicy: CompilationPolicy) throws(MachineDefinitionFailure) -> CompiledMechanicalModel {
        try compile(using: ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions()),
            definitionPolicy: definitionPolicy, compilationPolicy: compilationPolicy)
    }

    public func compile<Compiler: MechanicalModelCompiling>(using compiler: Compiler,
        definitionPolicy: MachineDefinitionPolicy, compilationPolicy: CompilationPolicy) throws(MachineDefinitionFailure) -> CompiledMechanicalModel {
        let descriptor = try makeDescriptor(policy: definitionPolicy)
        do { return try compiler.compile(descriptor, policy: compilationPolicy) }
        catch { throw .compilation(error) }
    }
}

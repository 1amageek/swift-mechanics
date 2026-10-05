public struct ParticleFlowModel: Equatable, Sendable {
    public let identity: ParticleFlowIdentity
    public let material: ParticleFlowMaterial
    public let gravity: Vector3
    public let ghosts: [PrescribedFlowGhost]
    public let capability: ParticleFlowCapability
    public init(identity: ParticleFlowIdentity, material: ParticleFlowMaterial, gravity: Vector3,
                ghosts: [PrescribedFlowGhost], capability: ParticleFlowCapability) {
        self.identity = identity; self.material = material; self.gravity = gravity
        self.ghosts = ghosts; self.capability = capability
    }
}

public struct FlowParticle: Equatable, Sendable {
    public let id: UInt64
    public let mass: Double
    public let position: Vector3
    public let velocity: Vector3
    public let viscousHeat: Double
    public init(id: UInt64, mass: Double, position: Vector3, velocity: Vector3,
                viscousHeat: Double) throws(ParticleFlowError) {
        guard mass.isFinite, mass > 0, viscousHeat.isFinite, viscousHeat >= 0 else { throw .invalidInput }
        self.id = id; self.mass = mass; self.position = position; self.velocity = velocity
        self.viscousHeat = viscousHeat
    }
}

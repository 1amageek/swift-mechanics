/// Supplied quadrature volume and density, not a finite particle mass or rigid-body inertia.
public struct PrescribedFlowGhost: Equatable, Sendable {
    public let id: UInt64
    public let volume: Double
    public let density: Double
    public let referencePosition: Vector3
    public let velocity: Vector3
    public let referenceTime: Double
    public init(id: UInt64, volume: Double, density: Double, referencePosition: Vector3,
                velocity: Vector3, referenceTime: Double) throws(ParticleFlowError) {
        guard volume.isFinite, volume > 0, density.isFinite, density > 0,
              referenceTime.isFinite else { throw .invalidInput }
        self.id = id; self.volume = volume; self.density = density
        self.referencePosition = referencePosition; self.velocity = velocity; self.referenceTime = referenceTime
    }
}

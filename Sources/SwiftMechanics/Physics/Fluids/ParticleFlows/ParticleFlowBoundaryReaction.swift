public struct ParticleFlowBoundaryReaction: Equatable, Sendable {
    public let ghostID: UInt64
    /// Force on the prescribed boundary, opposite the original force on finite fluid.
    public let force: Vector3
    /// Power supplied to finite fluid by prescribed boundary motion.
    public let prescribedMechanicalPower: Double
    /// Power supplied by the fixed-density ghost pressure reservoir.
    public let pressureReservoirPower: Double
}

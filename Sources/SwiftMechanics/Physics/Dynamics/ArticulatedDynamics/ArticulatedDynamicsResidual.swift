public struct ArticulatedDynamicsResidual: Sendable {
    public let originalGeneralizedInertialForce: [Double]
    public let normalizedInfinityNorm: Double
    public let referenceScale: Double
    public let threshold: Double
    public let originalVirtualPowerResidualWatts: Double
}

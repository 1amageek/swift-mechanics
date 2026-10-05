public struct GyroscopicRotorResponse: Equatable, Sendable {
    /// Torques applied to the rotor, in the world frame.
    public let requiredTorque: Vector3, motorTorque: Vector3, bearingTorque: Vector3
    /// Equal-and-opposite torques applied to the carrier.
    public let motorReaction: Vector3, bearingReaction: Vector3
    public let kineticEnergy: Double, energyRate: Double, carrierPower: Double, relativeMotorPower: Double
    public let powerResidual: Double
}

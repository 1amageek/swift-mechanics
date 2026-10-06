public struct RetimingCoordinateCertificate: Equatable, Sendable {
    public let speedRange: RetimingInterval
    public let accelerationRange: RetimingInterval
    public let effortRange: RetimingInterval
    public let displacement: Double
    /// Original body-equation generalized inertia action on segment displacement.
    public let originalInertiaCoefficient: Double
    public let staticEffort: Double
    internal init(speedRange: RetimingInterval, accelerationRange: RetimingInterval, effortRange: RetimingInterval,
                  displacement: Double, originalInertiaCoefficient: Double, staticEffort: Double) {
        self.speedRange = speedRange; self.accelerationRange = accelerationRange; self.effortRange = effortRange
        self.displacement = displacement; self.originalInertiaCoefficient = originalInertiaCoefficient; self.staticEffort = staticEffort
    }
}

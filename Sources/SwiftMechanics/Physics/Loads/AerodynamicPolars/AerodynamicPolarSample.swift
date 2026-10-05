public struct AerodynamicPolarSample: Sendable, Equatable {
    public let angle: Double
    public let liftCoefficient: Double
    public let dragCoefficient: Double
    public init(angle: Double, liftCoefficient: Double, dragCoefficient: Double) throws(LoadError) {
        guard angle.isFinite, abs(angle) <= Double.pi, liftCoefficient.isFinite,
              dragCoefficient.isFinite, dragCoefficient >= 0 else { throw .invalidInput }
        self.angle = angle; self.liftCoefficient = liftCoefficient; self.dragCoefficient = dragCoefficient
    }
}

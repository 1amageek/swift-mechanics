public struct GyroscopicRotor: Equatable, Sendable {
    public let transverseInertia: Double, polarInertia: Double, maximumSpeed: Double, maximumAcceleration: Double
    public init(transverseInertia: Double, polarInertia: Double, maximumSpeed: Double,
                maximumAcceleration: Double) throws(LoadError) {
        guard transverseInertia.isFinite, polarInertia.isFinite, maximumSpeed.isFinite, maximumAcceleration.isFinite,
              transverseInertia > 0, polarInertia > 0, polarInertia / 2 <= transverseInertia,
              maximumSpeed > 0, maximumAcceleration > 0 else { throw .invalidInput }
        self.transverseInertia = transverseInertia; self.polarInertia = polarInertia
        self.maximumSpeed = maximumSpeed; self.maximumAcceleration = maximumAcceleration
    }
}

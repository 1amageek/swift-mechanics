public struct MassProperties2D: Equatable, Sendable {
    public let mass: Double
    public let centerX: Double
    public let centerY: Double
    public let polarInertiaAtCenter: Double

    public init(mass: Double, centerX: Double, centerY: Double, polarInertiaAtCenter: Double) throws(ModelError) {
        guard mass.isFinite, mass > 0 else { throw .invalidMass }
        guard centerX.isFinite, centerY.isFinite else { throw .invalidDimensions }
        guard polarInertiaAtCenter.isFinite, polarInertiaAtCenter > 0 else { throw .nonPositiveInertia }
        self.mass = mass
        self.centerX = centerX
        self.centerY = centerY
        self.polarInertiaAtCenter = polarInertiaAtCenter
    }
}

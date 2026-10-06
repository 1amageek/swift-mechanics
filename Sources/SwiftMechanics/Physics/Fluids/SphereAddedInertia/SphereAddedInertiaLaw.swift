public struct SphereAddedInertiaLaw: Equatable, Sendable {
    public let radius: Double, fluidDensity: Double, displacedMass: Double, addedMass: Double
    public let maximumSpeed: Double, maximumAcceleration: Double
    public init(radius: Double, fluidDensity: Double, maximumSpeed: Double, maximumAcceleration: Double) throws(LoadError) {
        guard radius.isFinite, fluidDensity.isFinite, maximumSpeed.isFinite, maximumAcceleration.isFinite,
              radius > 0, fluidDensity > 0, maximumSpeed > 0, maximumAcceleration > 0 else { throw .invalidInput }
        let volume = (4 * Double.pi / 3) * radius * radius * radius
        let displaced = fluidDensity * volume, added = displaced / 2
        guard volume.isFinite, volume > 0, displaced.isFinite, added.isFinite, added > 0, (displaced + added).isFinite else { throw .nonFiniteResult }
        self.radius = radius; self.fluidDensity = fluidDensity; self.displacedMass = displaced; self.addedMass = added
        self.maximumSpeed = maximumSpeed; self.maximumAcceleration = maximumAcceleration
    }
}

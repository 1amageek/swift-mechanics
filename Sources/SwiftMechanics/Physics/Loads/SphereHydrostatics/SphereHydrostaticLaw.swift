public struct SphereHydrostaticLaw: Sendable, Equatable {
    public let radius: Double
    public let density: Double
    public let gravitationalAcceleration: Double
    public init(radius: Double, density: Double, gravitationalAcceleration: Double) throws(LoadError) {
        guard radius.isFinite, radius > 0, density.isFinite, density > 0,
              gravitationalAcceleration.isFinite, gravitationalAcceleration > 0 else { throw .invalidInput }
        self.radius = radius; self.density = density; self.gravitationalAcceleration = gravitationalAcceleration
    }
}

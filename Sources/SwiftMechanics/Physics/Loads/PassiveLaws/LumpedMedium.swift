public struct LumpedMedium: Equatable, Sendable {
    public let density: Double
    public let velocity: Vector3
    public let gravity: Vector3
    public init(density: Double, velocity: Vector3, gravity: Vector3) throws(LoadError) {
        guard density.isFinite, density > 0 else { throw .invalidInput }
        self.density = density; self.velocity = velocity; self.gravity = gravity
    }
}

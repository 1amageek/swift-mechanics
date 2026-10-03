import MechanicsCore
public struct GravitySample: Equatable, Sendable {
    public let point: Vector3
    public let mass: Double
    public init(point: Vector3, mass: Double) throws(LoadError) {
        guard mass.isFinite, mass > 0 else { throw .invalidInput }
        self.point = point; self.mass = mass
    }
}

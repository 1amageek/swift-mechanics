import MechanicsCore
public struct GranularMotion: Equatable, Sendable {
    public let position: Vector3, velocity: Vector3, angularVelocity: Vector3
    public init(position: Vector3, velocity: Vector3 = .zero, angularVelocity: Vector3 = .zero) {
        self.position=position; self.velocity=velocity; self.angularVelocity=angularVelocity
    }
}

import MechanicsCore
import MechanicsModel
public struct BodyInertiaDirection: Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let mass: Double
    public let centerOfMass: Vector3
    public let inertiaAtCenter: Matrix3
    public init(body: EntityID, frame: EntityID, mass: Double = 0, centerOfMass: Vector3 = .zero, inertiaAtCenter: Matrix3 = .zero) {
        self.body=body; self.frame=frame; self.mass=mass; self.centerOfMass=centerOfMass; self.inertiaAtCenter=inertiaAtCenter
    }
}

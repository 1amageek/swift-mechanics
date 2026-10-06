internal final class ToothRigidResult: Sendable {
    let acceleration: [Double]
    let contactForce: [Double]
    let energy: MechanicalEnergy
    init(acceleration: [Double], contactForce: [Double], energy: MechanicalEnergy) {
        self.acceleration=acceleration; self.contactForce=contactForce; self.energy=energy
    }
}

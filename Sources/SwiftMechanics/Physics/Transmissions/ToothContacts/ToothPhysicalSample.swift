internal final class ToothPhysicalSample: Sendable {
    let acceleration: [Double]
    let contactForce: [Double]
    let observations: [ToothContactObservation]
    let histories: [ContactHistory]
    let energy: MechanicalEnergy
    let storedEnergy: Double
    let dissipationPower: Double
    init(acceleration: [Double], contactForce: [Double], observations: [ToothContactObservation], histories: [ContactHistory],
         energy: MechanicalEnergy, storedEnergy: Double, dissipationPower: Double) {
        self.acceleration=acceleration; self.contactForce=contactForce; self.observations=observations; self.histories=histories
        self.energy=energy; self.storedEnergy=storedEnergy; self.dissipationPower=dissipationPower
    }
}

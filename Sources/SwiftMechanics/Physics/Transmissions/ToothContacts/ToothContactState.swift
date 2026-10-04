public final class ToothContactState: Sendable {
    public let model: ToothContactModel
    public let physical: KinematicState
    public let histories: [ContactHistory]
    public let observations: [ToothContactObservation]
    public let generalizedContactForce: [Double]
    public let energy: MechanicalEnergy
    public let contactStoredEnergy: Double
    public let initialTotalEnergy: Double
    public let accumulatedDriveWork: Double
    public let accumulatedDissipation: Double
    public let originalEnergyDefect: Double
    public let acceptedSteps: UInt64
    internal init(model: ToothContactModel, physical: KinematicState, histories: [ContactHistory], sample: ToothPhysicalSample,
                  initialTotalEnergy: Double, driveWork: Double, dissipation: Double, defect: Double, steps: UInt64) {
        self.model=model; self.physical=physical; self.histories=histories; observations=sample.observations
        generalizedContactForce=sample.contactForce; energy=sample.energy; contactStoredEnergy=sample.storedEnergy
        self.initialTotalEnergy=initialTotalEnergy; accumulatedDriveWork=driveWork; accumulatedDissipation=dissipation
        originalEnergyDefect=defect; acceptedSteps=steps
    }
}

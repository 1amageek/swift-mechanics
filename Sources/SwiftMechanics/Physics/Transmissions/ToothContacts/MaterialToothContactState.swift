public final class MaterialToothContactState: Sendable {
    public let model: ToothContactModel
    public let physical: KinematicState
    public let histories: [ContactHistory]
    public let observations: [MaterialToothContactSample]
    public let generalizedContactForce: [Double]
    public let energy: MechanicalEnergy
    public let normalStoredEnergy: Double
    public let tangentialStoredEnergy: Double
    public let cohesivePotentialEnergy: Double
    public let normalDissipationPower: Double
    public let resistanceDissipationPower: Double
    public let initialTotalEnergy: Double
    public let accumulatedDriveWork: Double
    public let accumulatedNormalDissipation: Double
    public let accumulatedResistanceDissipation: Double
    public let accumulatedTangentialDissipation: Double
    public let originalEnergyDefect: Double
    public let acceptedSteps: UInt64
    public var contactStoredEnergy: Double { normalStoredEnergy+tangentialStoredEnergy+cohesivePotentialEnergy }
    public var accumulatedDissipation: Double { accumulatedNormalDissipation+accumulatedResistanceDissipation+accumulatedTangentialDissipation }
    internal init(model: ToothContactModel, physical: KinematicState, sample: ToothMaterialSample, initialEnergy: Double,
                  drive: Double, normalLoss: Double, resistanceLoss: Double, tangentLoss: Double, defect: Double, steps: UInt64) {
        self.model=model; self.physical=physical; histories=sample.histories; observations=sample.observations
        generalizedContactForce=sample.rigid.contactForce; energy=sample.rigid.energy
        normalStoredEnergy=sample.normal; tangentialStoredEnergy=sample.tangent; cohesivePotentialEnergy=sample.cohesion
        normalDissipationPower=sample.normalPower; resistanceDissipationPower=sample.resistancePower
        initialTotalEnergy=initialEnergy; accumulatedDriveWork=drive; accumulatedNormalDissipation=normalLoss
        accumulatedResistanceDissipation=resistanceLoss; accumulatedTangentialDissipation=tangentLoss
        originalEnergyDefect=defect; acceptedSteps=steps
    }
}

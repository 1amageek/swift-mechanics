public struct WheeledAssemblyEvaluation: Sendable {
    public let kinematic: CompiledKinematicState
    public let snapshot: KinematicSnapshot
    public let solution: DynamicsSolution
    public let energy: MechanicalEnergy
    public let chassisInertialWrench: BodyWrenchEvidence
    public let rearSuspension, frontSuspension: ScalarLoadResponse
    public let actuation: WheeledAssemblyActuation
    public let roadSource: SourceProvenance
    public let suppliedRearNormalForce, suppliedFrontNormalForce: Double
    public let storedEnergy, roadPower, motorPower, steeringPower, brakeLossPower, suspensionLossPower: Double
    public let instantaneousPowerResidual: Double
    public let externalForce, externalTorqueAtWorldOrigin: Vector3
    internal init(kinematic: CompiledKinematicState, snapshot: KinematicSnapshot, solution: DynamicsSolution, energy: MechanicalEnergy,
                  chassisInertialWrench: BodyWrenchEvidence, rearSuspension: ScalarLoadResponse, frontSuspension: ScalarLoadResponse,
                  actuation: WheeledAssemblyActuation, roadSource: SourceProvenance, suppliedRearNormalForce: Double,
                  suppliedFrontNormalForce: Double, storedEnergy: Double, roadPower: Double, motorPower: Double,
                  steeringPower: Double, brakeLossPower: Double, suspensionLossPower: Double,
                  instantaneousPowerResidual: Double, externalForce: Vector3, externalTorqueAtWorldOrigin: Vector3) {
        self.kinematic=kinematic; self.snapshot=snapshot; self.solution=solution; self.energy=energy; self.chassisInertialWrench=chassisInertialWrench
        self.rearSuspension=rearSuspension; self.frontSuspension=frontSuspension; self.actuation=actuation; self.roadSource=roadSource
        self.suppliedRearNormalForce=suppliedRearNormalForce; self.suppliedFrontNormalForce=suppliedFrontNormalForce
        self.storedEnergy=storedEnergy; self.roadPower=roadPower; self.motorPower=motorPower; self.steeringPower=steeringPower
        self.brakeLossPower=brakeLossPower; self.suspensionLossPower=suspensionLossPower; self.instantaneousPowerResidual=instantaneousPowerResidual
        self.externalForce=externalForce; self.externalTorqueAtWorldOrigin=externalTorqueAtWorldOrigin
    }
}

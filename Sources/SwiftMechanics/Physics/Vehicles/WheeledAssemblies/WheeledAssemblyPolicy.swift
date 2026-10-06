public struct WheeledAssemblyPolicy: Sendable {
    public let maximumTimeStep, maximumSteeringAngle, maximumRoadForce, maximumRoadTorque, maximumRoadLeverArm: Double
    public let maximumCumulativeEnergyDefect: Double
    public let maximumWheelSpin, maximumRootLinearSpeed, maximumRootAngularSpeed: Double
    public let powerTolerance, energyTolerance, linearMomentumTolerance, angularMomentumTolerance: NumericalTolerance
    public let dynamicsAdmission: DynamicsAdmission
    public let dynamicsSolve: DynamicsSolvePolicy
    public init(maximumTimeStep: Double, maximumSteeringAngle: Double, maximumRoadForce: Double,
                maximumRoadTorque: Double, maximumRoadLeverArm: Double, maximumCumulativeEnergyDefect: Double,
                maximumWheelSpin: Double, maximumRootLinearSpeed: Double, maximumRootAngularSpeed: Double,
                powerTolerance: NumericalTolerance, energyTolerance: NumericalTolerance,
                linearMomentumTolerance: NumericalTolerance, angularMomentumTolerance: NumericalTolerance,
                dynamicsAdmission: DynamicsAdmission, dynamicsSolve: DynamicsSolvePolicy) throws(WheeledAssemblyFailure) {
        let positive=[maximumTimeStep,maximumSteeringAngle,maximumRoadForce,maximumRoadTorque,maximumRoadLeverArm,
                      maximumWheelSpin,maximumRootLinearSpeed,maximumRootAngularSpeed]
        guard positive.allSatisfy({ $0.isFinite && $0 > 0 }), maximumSteeringAngle < Double.pi/2,
              maximumCumulativeEnergyDefect.isFinite, maximumCumulativeEnergyDefect >= 0,
              dynamicsSolve.coordinateScales.count == 11 else { throw .refusal(.invalidInput) }
        // A relative acceptance band of one would admit a force/energy defect as large as its original scale.
        guard powerTolerance.relative < 1, energyTolerance.relative < 1,
              linearMomentumTolerance.relative < 1, angularMomentumTolerance.relative < 1 else { throw .refusal(.invalidInput) }
        self.maximumTimeStep=maximumTimeStep; self.maximumSteeringAngle=maximumSteeringAngle
        self.maximumRoadForce=maximumRoadForce; self.maximumRoadTorque=maximumRoadTorque
        self.maximumRoadLeverArm=maximumRoadLeverArm; self.maximumCumulativeEnergyDefect=maximumCumulativeEnergyDefect
        self.maximumWheelSpin=maximumWheelSpin; self.maximumRootLinearSpeed=maximumRootLinearSpeed; self.maximumRootAngularSpeed=maximumRootAngularSpeed
        self.powerTolerance=powerTolerance; self.energyTolerance=energyTolerance
        self.linearMomentumTolerance=linearMomentumTolerance; self.angularMomentumTolerance=angularMomentumTolerance
        self.dynamicsAdmission=dynamicsAdmission; self.dynamicsSolve=dynamicsSolve
    }
}

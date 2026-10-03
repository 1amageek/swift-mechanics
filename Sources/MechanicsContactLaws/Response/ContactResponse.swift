import MechanicsCore
public struct ContactResponse: Sendable {
    public let forceOnB: Vector3
    public let coupleOnB: Vector3
    public let compressiveNormalForce: Double
    public let cohesiveNormalForce: Double
    public let tangentialForceFirst: Double
    public let tangentialForceSecond: Double
    public let normalForcePenetrationDerivative: Double
    public let normalForceVelocityDerivative: Double
    public let normalStoredEnergy: Double
    public let tangentialStoredEnergy: Double
    public let cohesivePotentialEnergy: Double
    public let completeCohesiveSeparationWork: Double
    public let normalDissipationPower: Double
    public let resistanceDissipationPower: Double
    public let tangentialDissipationEnergy: Double
    public let relativeMechanicalPower: Double
    public let frictionConeUtilization: Double
    public let frictionRegime: ContactFrictionRegime
    public let originalTangentialEnergyResidual: Double
    public let originalPowerResidual: Double
    public let acceptedHistorySequence: UInt64
    public let trialHistory: ContactHistory
}

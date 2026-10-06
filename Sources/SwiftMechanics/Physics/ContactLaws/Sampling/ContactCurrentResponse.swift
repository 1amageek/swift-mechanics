public struct ContactCurrentResponse: Sendable {
    public let acceptedHistory: ContactHistory
    public let forceOnB: Vector3
    public let coupleOnB: Vector3
    public let compressiveNormalForce: Double
    public let elasticNormalForce: Double
    public let cohesiveNormalForce: Double
    public let tangentialForceFirst: Double
    public let tangentialForceSecond: Double
    public let normalStoredEnergy: Double
    public let tangentialStoredEnergy: Double
    public let cohesivePotentialEnergy: Double
    public let completeCohesiveSeparationWork: Double
    public let normalDissipationPower: Double
    public let resistanceDissipationPower: Double
    public let relativeMechanicalPower: Double
    public let elasticPotentialRatePower: Double
    public let staticFrictionConeUtilization: Double
    public let originalPowerResidual: Double
    public let originalRatePowerResidual: Double
    public let derivatives: ContactCurrentDerivatives
}

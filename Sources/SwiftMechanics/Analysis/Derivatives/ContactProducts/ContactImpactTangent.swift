public struct ContactImpactTangent: Sendable {
    public let pair: ContactLawPair
    public let approachSpeed: Double
    public let incomingNormalEnergy: Double
    public let direction: ContactImpactDirection
    public let primal: ContactImpactPrediction
    public let minimumApproachSpeed: Double
    public let maximumApproachSpeed: Double
    public let effectiveRestitution: Double
    public let reboundSpeed: Double
    public let retainedNormalEnergy: Double
    public let lostNormalEnergy: Double
}

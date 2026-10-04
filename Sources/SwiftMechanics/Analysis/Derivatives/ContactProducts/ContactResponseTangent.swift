public struct ContactResponseTangent: Sendable {
    public let source: ContactInput
    public let pair: ContactLawPair
    public let acceptedHistory: ContactHistory
    public let primal: ContactResponse
    public let direction: ContactDirection
    public let validity: ContactDerivativeValidity
    public let forceOnB: Vector3
    public let compressiveNormalForce: Double
    public let normalStoredEnergy: Double
    public let normalDissipationPower: Double
    public let relativeMechanicalPower: Double
}

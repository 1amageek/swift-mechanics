public struct ContactDerivativeValidity: Sendable {
    public let branch: ContactDerivativeBranch
    public let minimumSeparation: Double
    public let maximumSeparation: Double
    public let minimumNormalVelocity: Double
    public let maximumNormalVelocity: Double
}

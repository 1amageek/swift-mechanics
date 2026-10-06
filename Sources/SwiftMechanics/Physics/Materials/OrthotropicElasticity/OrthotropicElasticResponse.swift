public struct OrthotropicElasticResponse: Sendable {
    public let stress: SymmetricTensor
    public let energyDensity: Double
}

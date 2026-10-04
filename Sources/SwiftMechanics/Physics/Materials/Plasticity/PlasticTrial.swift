/// Candidate history is accepted only when the caller chooses it as the next input.
public struct PlasticTrial: Sendable {
    public let history: PlasticHistory
    public let secondPiolaStress: SymmetricTensor
    public let energyDensity: Double
    public let dissipationIncrement: Double
    public let plasticMultiplierIncrement: Double
    public let yieldResidual: Double
    public let isPlastic: Bool
}

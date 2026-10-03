/// Immutable material-reference history. α is accumulated equivalent plastic strain.
public struct PlasticHistory: Equatable, Sendable {
    public let material: J2Plasticity
    public let plasticGreenStrain: SymmetricTensor
    public let accumulatedPlasticStrain: Double

    internal init(material: J2Plasticity, plasticGreenStrain: SymmetricTensor, accumulatedPlasticStrain: Double) {
        self.material = material
        self.plasticGreenStrain = plasticGreenStrain
        self.accumulatedPlasticStrain = accumulatedPlasticStrain
    }
}

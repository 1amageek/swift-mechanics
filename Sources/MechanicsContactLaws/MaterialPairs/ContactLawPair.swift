import MechanicsModel
public struct ContactLawPair: Equatable, Sendable {
    public let firstMaterial: ModelReference
    public let secondMaterial: ModelReference
    public let parameters: ContactResolvedParameters
    public let lossPolicy: ContactLossPolicy
    public let provenance: ContactPairProvenance
    internal init(firstMaterial: ModelReference, secondMaterial: ModelReference, parameters: ContactResolvedParameters,
                  lossPolicy: ContactLossPolicy, provenance: ContactPairProvenance) {
        self.firstMaterial=firstMaterial; self.secondMaterial=secondMaterial; self.parameters=parameters
        self.lossPolicy=lossPolicy; self.provenance=provenance
    }
}

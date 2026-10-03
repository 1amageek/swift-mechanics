import MechanicsContactLaws
public struct GranularBinding: Sendable {
    public let firstParticle: Int
    public let secondParticle: Int?
    public let boundary: Int?
    public let identity: ContactIdentity
    public let law: ContactLawPair
    internal init(firstParticle: Int, secondParticle: Int?, boundary: Int?, identity: ContactIdentity, law: ContactLawPair) {
        self.firstParticle=firstParticle; self.secondParticle=secondParticle; self.boundary=boundary; self.identity=identity; self.law=law
    }
}

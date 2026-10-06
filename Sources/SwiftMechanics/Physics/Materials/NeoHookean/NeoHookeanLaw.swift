public struct NeoHookeanLaw: Equatable, Sendable {
    public let shearModulus: Double
    public let lameLambda: Double
    public let domain: StrainDomain
    public init(shearModulus: Double, lameLambda: Double, domain: StrainDomain) throws(MaterialError) {
        guard shearModulus.isFinite, shearModulus > 0, lameLambda.isFinite, lameLambda >= 0 else {
            throw .invalidParameter(name: "neoHookeanLaw")
        }
        self.shearModulus=shearModulus; self.lameLambda=lameLambda; self.domain=domain
    }
}

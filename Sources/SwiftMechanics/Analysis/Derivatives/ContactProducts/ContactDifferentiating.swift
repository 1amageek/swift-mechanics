public protocol ContactDifferentiating: Sendable {
    func contact(input: ContactInput, pair: ContactLawPair, accepted: ContactHistory,
                 direction: ContactDirection, policy: ContactDerivativePolicy,
                 work: inout ContactDerivativeWork) throws(ContactDerivativeError) -> ContactResponseTangent
    func impact(pair: ContactLawPair, approachSpeed: Double, incomingNormalEnergy: Double,
                direction: ContactImpactDirection, policy: ContactDerivativePolicy,
                work: inout ContactDerivativeWork) throws(ContactDerivativeError) -> ContactImpactTangent
}

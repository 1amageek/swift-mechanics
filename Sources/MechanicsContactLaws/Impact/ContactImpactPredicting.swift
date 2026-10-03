public protocol ContactImpactPredicting: Sendable {
    func predict(pair: ContactLawPair, approachSpeed: Double, incomingNormalEnergy: Double,
                 work: inout ContactWork) throws(ContactLawError) -> ContactImpactPrediction
}

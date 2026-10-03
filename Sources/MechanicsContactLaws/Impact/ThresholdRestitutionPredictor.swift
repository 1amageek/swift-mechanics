public struct ThresholdRestitutionPredictor: ContactImpactPredicting, Sendable {
    public init() {}
    public func predict(pair: ContactLawPair, approachSpeed: Double, incomingNormalEnergy: Double,
                        work: inout ContactWork) throws(ContactLawError) -> ContactImpactPrediction {
        try work.consume(operations:128,scalarStorage:64,records:1)
        try contactAccountPair(pair,work:&work)
        guard approachSpeed.isFinite, approachSpeed >= 0, incomingNormalEnergy.isFinite, incomingNormalEnergy >= 0,
              (approachSpeed == 0) == (incomingNormalEnergy == 0) else { throw .invalidInput }
        guard case .separateImpact(let coefficient,let threshold)=pair.lossPolicy else { throw .incompatibleLossPolicy }
        let e=approachSpeed < threshold ? 0 : coefficient
        let retained=try contactFinite(e*e*incomingNormalEnergy)
        let loss=try contactFinite((1-e*e)*incomingNormalEnergy)
        let rebound=try contactFinite(e*approachSpeed)
        try work.checkCancellation()
        return ContactImpactPrediction(effectiveRestitution:e,reboundSpeed:rebound,retainedNormalEnergy:retained,lostNormalEnergy:loss)
    }
}

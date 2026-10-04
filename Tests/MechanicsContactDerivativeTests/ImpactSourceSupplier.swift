import SwiftMechanics

struct ImpactSourceSupplier: ContactImpactPredicting {
    func predict(pair: ContactLawPair, approachSpeed: Double, incomingNormalEnergy: Double,
                 work: inout ContactWork) throws(ContactLawError) -> ContactImpactPrediction {
        try ThresholdRestitutionPredictor().predict(pair:pair,approachSpeed:approachSpeed,incomingNormalEnergy:incomingNormalEnergy+1,work:&work)
    }
}

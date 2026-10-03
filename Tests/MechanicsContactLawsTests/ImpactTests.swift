import MechanicsContactLaws
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ImpactTests {
    @Test func thresholdAndEnergyFractionsAreIndependentOfContinuousDamping() throws {
        let pair=try ContactFixtures.pair(loss:.separateImpact(restitution:0.6,thresholdSpeed:1))
        let predictor:any ContactImpactPredicting=ThresholdRestitutionPredictor(); var work=try ContactFixtures.work()
        let below=try predictor.predict(pair:pair,approachSpeed:0.5,incomingNormalEnergy:2,work:&work)
        #expect(below.effectiveRestitution == 0 && below.reboundSpeed == 0 && below.lostNormalEnergy == 2)
        let equality=try predictor.predict(pair:pair,approachSpeed:1,incomingNormalEnergy:4,work:&work)
        #expect(equality.effectiveRestitution == 0.6 && equality.reboundSpeed == 0.6)
        #expect(ContactFixtures.close(equality.retainedNormalEnergy,1.44))
        #expect(ContactFixtures.close(equality.lostNormalEnergy,2.56))
        #expect(ContactFixtures.close(equality.retainedNormalEnergy+equality.lostNormalEnergy,4))
        let above=try predictor.predict(pair:pair,approachSpeed:2,incomingNormalEnergy:8,work:&work)
        #expect(ContactFixtures.close(above.reboundSpeed,1.2))
        #expect(ContactFixtures.close(above.retainedNormalEnergy/8,0.36))
        let zero=try predictor.predict(pair:pair,approachSpeed:0,incomingNormalEnergy:0,work:&work)
        #expect(zero.lostNormalEnergy == 0)
        #expect(throws:ContactLawError.invalidInput) { try predictor.predict(pair:pair,approachSpeed:1,incomingNormalEnergy:0,work:&work) }
        #expect(throws:ContactLawError.incompatibleLossPolicy) { try predictor.predict(pair:ContactFixtures.pair(),approachSpeed:1,incomingNormalEnergy:1,work:&work) }
        #expect(throws:ContactLawError.invalidMaterial) { try ContactFixtures.pair(loss:.separateImpact(restitution:1.1,thresholdSpeed:1)) }
    }
}

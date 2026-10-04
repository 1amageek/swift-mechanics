import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PairingTests {
    @Test func seriesModulusMinimaAndSwappedOrderAreExplicit() throws {
        let service:any ContactMaterialPairing=SeriesContactPairing(); var work=try ContactFixtures.work()
        let a=try ContactFixtures.material("a",stiffness:2000,damping:6,modulus:1e6,friction:ContactFixtures.friction())
        let b=try ContactFixtures.material("b",stiffness:6000,damping:3,modulus:2e6,friction:ContactFixtures.friction(staticFirst:0.6,staticSecond:0.7,dynamicFirst:0.3,dynamicSecond:0.35))
        let x=try service.combine(first:a,second:b,selection:.linear(maximumPenetration:0.1,maximumNormalSpeed:10),lossPolicy:.compliantDampingOnly,resistanceRadius:0.1,override:nil,work:&work)
        let swapped=try service.combine(first:b,second:a,selection:.linear(maximumPenetration:0.1,maximumNormalSpeed:10),lossPolicy:.compliantDampingOnly,resistanceRadius:0.1,override:nil,work:&work)
        #expect(x.parameters == swapped.parameters)
        #expect(x.firstMaterial == a.reference && swapped.firstMaterial == b.reference)
        guard case .linear(let k,let c,_,_)=x.parameters.normal else { Issue.record("Linear selection must be preserved"); return }
        #expect(ContactFixtures.close(k,1500)); #expect(ContactFixtures.close(c,2))
        guard case .elasticCoulomb(let friction)=x.parameters.friction else { Issue.record("Friction required"); return }
        #expect(friction.staticFirst == 0.6 && friction.dynamicSecond == 0.35)
        let h=try service.combine(first:a,second:b,selection:.hertz(effectiveRadius:0.1,maximumPenetration:0.01,maximumNormalSpeed:10),lossPolicy:.compliantDampingOnly,resistanceRadius:0.1,override:nil,work:&work)
        guard case .hertz(let coefficient,_,_,_)=h.parameters.normal else { Issue.record("Hertz selection must be preserved"); return }
        let effective=1/((1-0.25*0.25)/1e6+(1-0.25*0.25)/2e6)
        #expect(ContactFixtures.close(coefficient,(4.0/3)*effective*0.1.squareRoot()))
    }
    @Test func orderedOverrideAndMaterialRevisionHaveObservableEffects() throws {
        let service:any ContactMaterialPairing=SeriesContactPairing(); var work=try ContactFixtures.work()
        let a=try ContactFixtures.material("a"),b=try ContactFixtures.material("b")
        let parameters=try ContactResolvedParameters(normal:.linear(stiffness:5000,damping:0,maximumPenetration:0.1,maximumNormalSpeed:10),friction:.none,
            resistance:ContactResistanceParameters(rollingCoefficient:0,spinningCoefficient:0,angularRegularization:0.1),resistanceRadius:0.1,cohesion:.none)
        let override=try ContactPairOverride(first:a.reference,second:b.reference,revision:7,parameters:parameters)
        let x=try service.combine(first:a,second:b,selection:.linear(maximumPenetration:0.1,maximumNormalSpeed:10),lossPolicy:.compliantDampingOnly,resistanceRadius:0.1,override:override,work:&work)
        #expect(x.provenance == .orderedCalibratedOverride(revision:7))
        #expect(try ContactFixtures.evaluate(ContactFixtures.input(),pair:x).compressiveNormalForce == 50)
        #expect(throws:ContactLawError.invalidOverrideOrder) { try service.combine(first:b,second:a,selection:.linear(maximumPenetration:0.1,maximumNormalSpeed:10),lossPolicy:.compliantDampingOnly,resistanceRadius:0.1,override:override,work:&work) }
        let edited=try ContactFixtures.material("a",revision:2)
        #expect(throws:ContactLawError.staleMaterial) { try service.combine(first:edited,second:b,selection:.linear(maximumPenetration:0.1,maximumNormalSpeed:10),lossPolicy:.compliantDampingOnly,resistanceRadius:0.1,override:override,work:&work) }
    }
    @Test func invalidMaterialsMixedFrictionAndDoubleNormalLossFail() throws {
        #expect(throws:ContactLawError.invalidMaterial) { try ContactFixtures.material("bad",poisson:0.5) }
        #expect(throws:ContactLawError.invalidMaterial) { try ContactFixtures.friction(staticFirst:0.2,dynamicFirst:0.4) }
        #expect(throws:ContactLawError.invalidMaterial) { try ContactFixtures.pair(selection:.hertz(effectiveRadius:0.01,maximumPenetration:0.02,maximumNormalSpeed:10)) }
        #expect(throws:ContactLawError.incompatibleLossPolicy) { try ContactFixtures.pair(damping:1,loss:.separateImpact(restitution:0.5,thresholdSpeed:1)) }
        #expect(throws:ContactLawError.incompatibleLossPolicy) { try ContactFixtures.pair(selection:.huntCrossley(effectiveRadius:0.1,maximumPenetration:0.01,maximumNormalSpeed:10),alpha:0.2,loss:.separateImpact(restitution:0.5,thresholdSpeed:1)) }
        let service:any ContactMaterialPairing=SeriesContactPairing(); var work=try ContactFixtures.work()
        #expect(throws:ContactLawError.incompatibleFriction) { try service.combine(first:ContactFixtures.material("a",friction:ContactFixtures.friction()),second:ContactFixtures.material("b"),selection:.linear(maximumPenetration:0.1,maximumNormalSpeed:10),lossPolicy:.compliantDampingOnly,resistanceRadius:1,override:nil,work:&work) }
    }
}

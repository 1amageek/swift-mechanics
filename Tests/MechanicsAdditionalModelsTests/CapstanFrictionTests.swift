import Testing
import SwiftMechanics
import Foundation

@Suite struct CapstanFrictionTests {
    let service: any CapstanFrictionEvaluating = CapstanFrictionEvaluator()
    func law(_ angle: Double = .pi) throws -> CapstanFrictionLaw {
        try CapstanFrictionLaw(wrapAngle: angle, staticCoefficient: 0.4, kineticCoefficient: 0.3,
                               maximumTension: 10000, maximumSlipSpeed: 10)
    }
    @Test func staticConeDoesNotInventTension() throws {
        var work = try AdditionalModelFixture.actuationWork()
        let p = try law()
        let r = try service.sticking(law: p, upstreamTension: 20, downstreamTension: 30, work: &work)
        #expect(r.sticking && r.upstreamTension == 20 && r.downstreamTension == 30)
        #expect(r.dissipatedPower == 0 && r.slipSpeed == 0)
        #expect(r.cableForce + r.downstreamTension - r.upstreamTension == 0)
        #expect(throws: ActuationError.outsideDomain) { try service.sticking(law: p, upstreamTension: 20, downstreamTension: 100, work: &work) }
    }
    @Test func slidingBothDirectionsAndEnergy() throws {
        var work = try AdditionalModelFixture.actuationWork()
        let p = try law()
        let positive = try service.sliding(law: p, lowTension: 20, slipSpeed: 2, work: &work)
        let negative = try service.sliding(law: p, lowTension: 20, slipSpeed: -2, work: &work)
        #expect(AdditionalModelFixture.near(positive.downstreamTension/positive.upstreamTension, exp(0.3 * .pi)))
        #expect(positive.upstreamTension == negative.downstreamTension)
        #expect(positive.cableForce == -negative.cableForce)
        #expect(positive.dissipatedPower == negative.dissipatedPower)
        #expect(AdditionalModelFixture.near(positive.cableForce*2 + positive.dissipatedPower, 0))
        #expect(AdditionalModelFixture.near(negative.cableForce * -2 + negative.dissipatedPower, 0))
        #expect(AdditionalModelFixture.near(positive.cableForce + positive.downstreamTension - positive.upstreamTension, 0))
        let zeroWrap = try service.sliding(law: law(0), lowTension: 20, slipSpeed: 2, work: &work)
        #expect(zeroWrap.cableForce == 0 && zeroWrap.dissipatedPower == 0)
    }
    @Test func invalidModesAndBounds() throws {
        var work = try AdditionalModelFixture.actuationWork()
        #expect(throws: ActuationError.invalidInput) { try service.sliding(law: law(), lowTension: 20, slipSpeed: 0, work: &work) }
        #expect(throws: ActuationError.invalidInput) { try service.sliding(law: law(), lowTension: 0, slipSpeed: 1, work: &work) }
        var exhausted = try AdditionalModelFixture.actuationWork(maximumWork: 19)
        #expect(throws: ActuationError.workExhausted) { try service.sliding(law: law(), lowTension: 20, slipSpeed: 1, work: &exhausted) }
        var cancelled = try AdditionalModelFixture.actuationWork(cancelled: true)
        #expect(throws: ActuationError.cancelled) { try service.sticking(law: law(), upstreamTension: 1, downstreamTension: 1, work: &cancelled) }
        #expect(throws: ActuationError.invalidLaw) {
            try CapstanFrictionLaw(wrapAngle: 1, staticCoefficient: 0.1, kineticCoefficient: 0.2, maximumTension: 1, maximumSlipSpeed: 1)
        }
    }
    @Test func nearEqualStaticTensionsAndLargeRatio() throws {
        var work = try AdditionalModelFixture.actuationWork()
        let noWrap = try CapstanFrictionLaw(wrapAngle: 0, staticCoefficient: 0, kineticCoefficient: 0,
                                            maximumTension: 1e301, maximumSlipSpeed: 1)
        #expect(throws: ActuationError.outsideDomain) {
            try service.sticking(law: noWrap, upstreamTension: 1e300, downstreamTension: 1e300.nextUp, work: &work)
        }
        let wide = try CapstanFrictionLaw(wrapAngle: 1000, staticCoefficient: 1, kineticCoefficient: 1,
                                          maximumTension: 1e200, maximumSlipSpeed: 1)
        let r = try service.sliding(law: wide, lowTension: 1e-300, slipSpeed: 1, work: &work)
        #expect(AdditionalModelFixture.near(log(r.downstreamTension)-log(r.upstreamTension), 1000))
        #expect(r.dissipatedPower > 0 && r.dissipatedPower.isFinite)
    }

}

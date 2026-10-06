import Testing
import SwiftMechanics

@Suite struct StribeckFrictionTests {
    let service: any StribeckFrictionEvaluating = StribeckFrictionEvaluator()
    func law() throws -> StribeckFrictionLaw { try StribeckFrictionLaw(coordinateKind: .translation, coulombEffort: 2, lowSpeedEffort: 5, stribeckRate: 1, regularizationRate: 0.2, viscousCoefficient: 0.5, maximumRate: 5) }
    func evaluate(_ x: Double) throws -> ScalarLoadResponse {
        var work = try NineServiceFixture.work()
        return try service.evaluate(law: law(), rate: x, work: &work)
    }
    @Test func independentAnalyticResponse() throws {
        let r = try evaluate(1.0)
        #expect(NineServiceFixture.near(r.dissipative, -3.6033565263841054))
        #expect(NineServiceFixture.near(r.potentialEnergy!, 0))
        #expect(NineServiceFixture.near(r.rateDerivative, 1.7042583923455057))
        #expect(r.active == 0)
    }
    @Test func directionalTangentAndSymmetry() throws {
        let x = 1.0, h = 1e-5, r = try evaluate(x)
        let plus = try evaluate(x+h), minus = try evaluate(x-h)
        #expect(NineServiceFixture.near(r.rateDerivative, (try plus.total() - (try minus.total()))/(2*h)))
        let reversed = try evaluate(-x)
        #expect(try NineServiceFixture.near(r.total(), -reversed.total()))
        #expect(NineServiceFixture.near(r.potentialEnergy!, reversed.potentialEnergy!))
    }
    @Test func originalEnergyOrDissipation() throws {
        let x = 1.0, r = try evaluate(x)
        #expect(NineServiceFixture.near(r.dissipatedPower, -r.dissipative*x))
        #expect(r.dissipatedPower >= 0 && r.potentialEnergy == 0)
        let zero = try evaluate(0)
        #expect(zero.dissipative == 0 && zero.dissipatedPower == 0)
    }
    @Test func invalidDomainAndNonfiniteRefusal() throws {
        #expect(throws: LoadError.invalidPassiveLaw) { try StribeckFrictionLaw(coordinateKind: .translation, coulombEffort: 2, lowSpeedEffort: 1, stribeckRate: 1, regularizationRate: 0.2, viscousCoefficient: 0.5, maximumRate: 5) }
        var work = try NineServiceFixture.work()
        #expect(throws: LoadError.outsideDomain) { try service.evaluate(law: law(), rate: 6, work: &work) }
        #expect(throws: LoadError.invalidInput) { try service.evaluate(law: law(), rate: .nan, work: &work) }
        let wide = try StribeckFrictionLaw(coordinateKind: .translation, coulombEffort: 1e308, lowSpeedEffort: 1e308, stribeckRate: 1, regularizationRate: 0.2, viscousCoefficient: 1e308, maximumRate: 5)
        #expect(throws: LoadError.nonFiniteResult) { try service.evaluate(law: wide, rate: 2, work: &work) }
    }
    @Test func workCapacityCancellationAndPhysicalInputPreserved() throws {
        let p = try law(), original = p
        var scarce = try NineServiceFixture.work(maximumWork: 0)
        #expect(throws: LoadError.workExhausted) { try service.evaluate(law: p, rate: 0, work: &scarce) }
        var small = try NineServiceFixture.work(maximumScalars: 0)
        #expect(throws: LoadError.capacityExceeded) { try service.evaluate(law: p, rate: 0, work: &small) }
        var cancelled = try NineServiceFixture.work(cancelled: true)
        #expect(throws: LoadError.cancelled) { try service.evaluate(law: p, rate: 0, work: &cancelled) }
        #expect(p == original)
    }
    @Test func velocityWeakeningStillDissipatesAndRestIsRegularized() throws {
        let rest = try evaluate(0), weakening = try evaluate(1)
        #expect(rest.rateDerivative == -25.5 && rest.dissipative == 0)
        #expect(weakening.rateDerivative > 0 && weakening.dissipatedPower > 0)
    }
}

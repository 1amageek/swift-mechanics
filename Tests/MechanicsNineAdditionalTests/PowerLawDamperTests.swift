import Testing
import SwiftMechanics

@Suite struct PowerLawDamperTests {
    let service: any PowerLawDamperEvaluating = PowerLawDamperEvaluator()
    func law() throws -> PowerLawDamperLaw { try PowerLawDamperLaw(coordinateKind: .translation, coefficient: 3, exponent: 1.5, maximumRate: 5) }
    func evaluate(_ x: Double) throws -> ScalarLoadResponse {
        var work = try NineServiceFixture.work()
        return try service.evaluate(law: law(), rate: x, work: &work)
    }
    @Test func independentAnalyticResponse() throws {
        let r = try evaluate(2.0)
        #expect(NineServiceFixture.near(r.dissipative, -8.485281374238571))
        #expect(NineServiceFixture.near(r.potentialEnergy!, 0))
        #expect(NineServiceFixture.near(r.rateDerivative, -6.3639610306789285))
        #expect(r.active == 0)
    }
    @Test func directionalTangentAndSymmetry() throws {
        let x = 2.0, h = 1e-5, r = try evaluate(x)
        let plus = try evaluate(x+h), minus = try evaluate(x-h)
        #expect(NineServiceFixture.near(r.rateDerivative, (try plus.total() - (try minus.total()))/(2*h)))
        let reversed = try evaluate(-x)
        #expect(try NineServiceFixture.near(r.total(), -reversed.total()))
        #expect(NineServiceFixture.near(r.potentialEnergy!, reversed.potentialEnergy!))
    }
    @Test func originalEnergyOrDissipation() throws {
        let x = 2.0, r = try evaluate(x)
        #expect(NineServiceFixture.near(r.dissipatedPower, -r.dissipative*x))
        #expect(r.dissipatedPower >= 0 && r.potentialEnergy == 0)
        let zero = try evaluate(0)
        #expect(zero.dissipative == 0 && zero.dissipatedPower == 0)
    }
    @Test func invalidDomainAndNonfiniteRefusal() throws {
        #expect(throws: LoadError.invalidPassiveLaw) { try PowerLawDamperLaw(coordinateKind: .translation, coefficient: 3, exponent: 0.5, maximumRate: 5) }
        var work = try NineServiceFixture.work()
        #expect(throws: LoadError.outsideDomain) { try service.evaluate(law: law(), rate: 6, work: &work) }
        #expect(throws: LoadError.invalidInput) { try service.evaluate(law: law(), rate: .nan, work: &work) }
        let wide = try PowerLawDamperLaw(coordinateKind: .translation, coefficient: 1e308, exponent: 2, maximumRate: 5)
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
    @Test func zeroRateLinearLimitAndZeroCoefficient() throws {
        var work = try NineServiceFixture.work()
        let linear = try PowerLawDamperLaw(coordinateKind: .rotation, coefficient: 3, exponent: 1, maximumRate: 5)
        let rest = try service.evaluate(law: linear, rate: 0, work: &work)
        #expect(rest.rateDerivative == -3 && rest.dissipative == 0)
        #expect(try evaluate(0).rateDerivative == 0)
        let disabled = try PowerLawDamperLaw(coordinateKind: .translation, coefficient: 0, exponent: 1e308, maximumRate: 5)
        let zero = try service.evaluate(law: disabled, rate: 4, work: &work)
        #expect(zero.dissipative == 0 && zero.rateDerivative == 0 && zero.dissipatedPower == 0)
    }
}

import Testing
import SwiftMechanics

@Suite struct FiniteExtensionSpringTests {
    let service: any FiniteExtensionSpringEvaluating = FiniteExtensionSpringEvaluator()
    func law() throws -> FiniteExtensionSpringLaw { try FiniteExtensionSpringLaw(coordinateKind: .translation, restCoordinate: 0, stiffness: 10, limitingExtension: 2, maximumDisplacement: 1.9, maximumRate: 5) }
    func evaluate(_ x: Double) throws -> ScalarLoadResponse {
        var work = try NineServiceFixture.work()
        return try service.evaluate(law: law(), coordinate: x, rate: 0, work: &work)
    }
    @Test func independentAnalyticResponse() throws {
        let r = try evaluate(1.0)
        #expect(NineServiceFixture.near(r.conservative, -13.333333333333334))
        #expect(NineServiceFixture.near(r.potentialEnergy!, 5.753641449035618))
        #expect(NineServiceFixture.near(r.coordinateDerivative, -22.22222222222222))
        #expect(r.active == 0)
    }
    @Test func directionalTangentAndSymmetry() throws {
        let x = 1.0, h = 1e-5, r = try evaluate(x)
        let plus = try evaluate(x+h), minus = try evaluate(x-h)
        #expect(NineServiceFixture.near(r.coordinateDerivative, (try plus.total() - (try minus.total()))/(2*h)))
        let reversed = try evaluate(-x)
        #expect(try NineServiceFixture.near(r.total(), -reversed.total()))
        #expect(NineServiceFixture.near(r.potentialEnergy!, reversed.potentialEnergy!))
    }
    @Test func originalEnergyOrDissipation() throws {
        let x = 1.0, r = try evaluate(x)
        let h = 1e-5
        let plus = try evaluate(x+h), minus = try evaluate(x-h)
        #expect(NineServiceFixture.near(r.conservative, -(plus.potentialEnergy! - minus.potentialEnergy!)/(2*h)))
        let tiny = try evaluate(1e-10)
        #expect(NineServiceFixture.near(tiny.potentialEnergy!, 5e-20, absolute: 1e-32, relative: 1e-7))
    }
    @Test func invalidDomainAndNonfiniteRefusal() throws {
        #expect(throws: LoadError.invalidPassiveLaw) { try FiniteExtensionSpringLaw(coordinateKind: .translation, restCoordinate: 0, stiffness: 10, limitingExtension: 2, maximumDisplacement: 2, maximumRate: 5) }
        var work = try NineServiceFixture.work()
        #expect(throws: LoadError.outsideDomain) { try service.evaluate(law: law(), coordinate: 4, rate: 0, work: &work) }
        #expect(throws: LoadError.invalidInput) { try service.evaluate(law: law(), coordinate: .nan, rate: 0, work: &work) }
        let wide = try FiniteExtensionSpringLaw(coordinateKind: .translation, restCoordinate: 0, stiffness: 1e308, limitingExtension: 3, maximumDisplacement: 2.9, maximumRate: 5)
        #expect(throws: LoadError.nonFiniteResult) { try service.evaluate(law: wide, coordinate: 2, rate: 0, work: &work) }
    }
    @Test func workCapacityCancellationAndPhysicalInputPreserved() throws {
        let p = try law(), original = p
        var scarce = try NineServiceFixture.work(maximumWork: 0)
        #expect(throws: LoadError.workExhausted) { try service.evaluate(law: p, coordinate: 0, rate: 0, work: &scarce) }
        var small = try NineServiceFixture.work(maximumScalars: 0)
        #expect(throws: LoadError.capacityExceeded) { try service.evaluate(law: p, coordinate: 0, rate: 0, work: &small) }
        var cancelled = try NineServiceFixture.work(cancelled: true)
        #expect(throws: LoadError.cancelled) { try service.evaluate(law: p, coordinate: 0, rate: 0, work: &cancelled) }
        #expect(p == original)
    }
    @Test func calibratedExtensionBoundaryHasNoClipping() throws {
        let boundary = try evaluate(1.9), rest = try evaluate(0)
        #expect(boundary.conservative < -100 && boundary.potentialEnergy! > 0)
        #expect(rest.conservative == 0 && rest.potentialEnergy == 0 && rest.coordinateDerivative == -10)
        #expect(throws: LoadError.outsideDomain) { try evaluate(1.90001) }
    }
}

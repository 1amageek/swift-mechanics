import Testing
import SwiftMechanics
import Foundation

@Suite struct PolytropicGasTests {
    let service: any PolytropicGasEvaluating = PolytropicGasEvaluator()
    func law(_ exponent: Double = 1.4) throws -> PolytropicGasLaw {
        try PolytropicGasLaw(referenceVolume: 2, area: 0.25, exponent: exponent, referencePressure: 300000,
                            ambientPressure: 100000, minimumStroke: -2, maximumStroke: 2)
    }
    @Test func polytropicPressureAndWorkDerivative() throws {
        var work = try AdditionalModelFixture.actuationWork()
        let p = try law(), x = -0.8, h = 1e-5
        let r = try service.evaluate(law: p, stroke: x, work: &work)
        let lo = try service.evaluate(law: p, stroke: x-h, work: &work)
        let hi = try service.evaluate(law: p, stroke: x+h, work: &work)
        #expect(AdditionalModelFixture.near(r.pressure, 300000 * pow(2/1.8, 1.4)))
        #expect(AdditionalModelFixture.near(r.forceDerivative, (hi.force-lo.force)/(2*h), absolute: 1e-4))
        #expect(AdditionalModelFixture.near(r.force, -(hi.potentialEnergy-lo.potentialEnergy)/(2*h), absolute: 1e-4))
    }
    @Test func isothermalLimitAndSmallStroke() throws {
        var work = try AdditionalModelFixture.actuationWork()
        let r = try service.evaluate(law: law(1), stroke: 1, work: &work)
        let near = try service.evaluate(law: law(1+1e-12), stroke: 1, work: &work)
        #expect(AdditionalModelFixture.near(r.potentialEnergy, -600000*log(1.125)+25000))
        #expect(AdditionalModelFixture.near(r.potentialEnergy, near.potentialEnergy))
        let tiny = try service.evaluate(law: law(), stroke: 1e-12, work: &work)
        #expect(AdditionalModelFixture.near(tiny.potentialEnergy, -50000e-12, absolute: 1e-18))
    }
    @Test func explicitPressureAndResourceFailures() throws {
        var work = try AdditionalModelFixture.actuationWork()
        #expect(throws: ActuationError.outsideDomain) { try service.evaluate(law: law(), stroke: -3, work: &work) }
        var small = try AdditionalModelFixture.actuationWork(maximumScalars: 19)
        #expect(throws: ActuationError.capacityExceeded) { try service.evaluate(law: law(), stroke: 0, work: &small) }
        var cancelled = try AdditionalModelFixture.actuationWork(cancelled: true)
        #expect(throws: ActuationError.cancelled) { try service.evaluate(law: law(), stroke: 0, work: &cancelled) }
        let stiff = try law(1e8)
        #expect(throws: ActuationError.nonfiniteResult) { try service.evaluate(law: stiff, stroke: -1, work: &work) }
        #expect(throws: ActuationError.invalidLaw) { try law(0) }
    }
}

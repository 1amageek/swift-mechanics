import Testing
import SwiftMechanics
import Foundation

@Suite struct SealedLiquidTests {
    let service: any SealedLiquidEvaluating = SealedLiquidEvaluator()
    func law() throws -> SealedLiquidLaw {
        try SealedLiquidLaw(referenceVolume: 2, area: 0.5, bulkModulus: 100000, referencePressure: 200000,
                           ambientPressure: 200000, minimumStroke: -1, maximumStroke: 1)
    }
    @Test func pressureAndConservativeDerivative() throws {
        var work = try AdditionalModelFixture.actuationWork()
        let p = try law(), x = -0.4, h = 1e-5
        let r = try service.evaluate(law: p, stroke: x, work: &work)
        let lo = try service.evaluate(law: p, stroke: x - h, work: &work)
        let hi = try service.evaluate(law: p, stroke: x + h, work: &work)
        #expect(AdditionalModelFixture.near(r.volume, 1.8))
        #expect(AdditionalModelFixture.near(r.pressure, 200000 - 100000 * log(0.9)))
        #expect(AdditionalModelFixture.near(r.force, -(hi.potentialEnergy - lo.potentialEnergy) / (2 * h), absolute: 1e-5))
        #expect(AdditionalModelFixture.near(r.forceDerivative, (hi.force - lo.force) / (2 * h), absolute: 1e-5))
        #expect(r.force > 0 && r.potentialEnergy > 0)
        #expect(work.used == 192)
    }
    @Test func tinyElasticStorageAndExpansion() throws {
        var work = try AdditionalModelFixture.actuationWork()
        let p = try law(), tiny = try service.evaluate(law: p, stroke: 1e-12, work: &work)
        #expect(tiny.potentialEnergy > 0)
        #expect(AdditionalModelFixture.near(tiny.potentialEnergy, 100000 * 0.25e-24 / 4, absolute: 1e-33))
        let expansion = try service.evaluate(law: p, stroke: 0.5, work: &work)
        #expect(expansion.force < 0 && expansion.pressure > 0)
        let reference = try service.evaluate(law: p, stroke: 0, work: &work)
        #expect(reference.force == 0 && reference.potentialEnergy == 0)
    }
    @Test func failuresAndBudgets() throws {
        let p = try law()
        var exhausted = try AdditionalModelFixture.actuationWork(maximumWork: 63)
        #expect(throws: ActuationError.workExhausted) { try service.evaluate(law: p, stroke: 0, work: &exhausted) }
        var cancelled = try AdditionalModelFixture.actuationWork(cancelled: true)
        #expect(throws: ActuationError.cancelled) { try service.evaluate(law: p, stroke: 0, work: &cancelled) }
        var work = try AdditionalModelFixture.actuationWork()
        #expect(throws: ActuationError.outsideDomain) { try service.evaluate(law: p, stroke: 2, work: &work) }
        #expect(throws: ActuationError.invalidInput) { try service.evaluate(law: p, stroke: .nan, work: &work) }
        #expect(throws: ActuationError.invalidLaw) {
            try SealedLiquidLaw(referenceVolume: 1, area: 1, bulkModulus: 1, referencePressure: 1,
                                ambientPressure: 0, minimumStroke: -1, maximumStroke: 1)
        }
    }
}

import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct LaminarHydraulicResistanceTests {

    @Test func originalPoiseuilleResistanceFixture() throws {
        // A fixed supplied resistance, not an inferred fluid geometry.
        let law: any HydraulicResistanceEvaluating = try LaminarHydraulicResistance(resistance: 250)
        var work = try HydraulicFixture.work()
        let r = try law.evaluate(pressureDifference: 100, work: &work)
        #expect(r.volumeFlow == 0.4 && r.dissipatedPower == 40)
        HydraulicFixture.balanced(r)
    }
    @Test func bidirectionalAndZeroFlow() throws {
        let law = try LaminarHydraulicResistance(resistance: 10)
        var work = try HydraulicFixture.work()
        for p in [-12.0, 0, 12] {
            let r = try law.evaluate(pressureDifference: p, work: &work)
            #expect(HydraulicFixture.near(r.volumeFlow, p/10))
            HydraulicFixture.balanced(r)
        }
    }
    @Test func independentSeriesCircuit() throws {
        let a = try LaminarHydraulicResistance(resistance: 2), b = try LaminarHydraulicResistance(resistance: 3)
        var work = try HydraulicFixture.work()
        let x = try a.evaluate(pressureDifference: 4, work: &work)
        let y = try b.evaluate(pressureDifference: 6, work: &work)
        #expect(x.volumeFlow == 2 && y.volumeFlow == 2)
        #expect(x.dissipatedPower + y.dissipatedPower == 20)
    }
    @Test func originalPressureDerivativeRefinement() throws {
        let law = try LaminarHydraulicResistance(resistance: 3)
        var work = try HydraulicFixture.work()
        for h in [1e-6, 5e-7] {
            let plus = try law.evaluate(pressureDifference: 2+h, work: &work)
            let minus = try law.evaluate(pressureDifference: 2-h, work: &work)
            #expect(HydraulicFixture.near((plus.volumeFlow-minus.volumeFlow)/(2*h), 1/3.0, absolute: 1e-8, relative: 1e-6))
        }
    }
    @Test func malformedLawAndQuery() throws {
        for x in [0.0, -1, .nan, .infinity] { #expect(throws: ActuationError.invalidLaw) { try LaminarHydraulicResistance(resistance: x) } }
        let law = try LaminarHydraulicResistance(resistance: 2)
        var work = try HydraulicFixture.work()
        #expect(throws: ActuationError.invalidInput) { try law.evaluate(pressureDifference: .nan, work: &work) }
    }
    @Test func overflowRefusesAndSampleIsPreserved() throws {
        let huge = try LaminarHydraulicResistance(resistance: Double.leastNonzeroMagnitude)
        var work = try HydraulicFixture.work()
        #expect(throws: ActuationError.nonfiniteResult) { try huge.evaluate(pressureDifference: 1, work: &work) }
        let law = try LaminarHydraulicResistance(resistance: 2)
        let before = try law.evaluate(pressureDifference: 1, work: &work)
        #expect(try law.evaluate(pressureDifference: 1, work: &work) == before)
    }
}

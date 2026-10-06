import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct HydraulicInertanceTests {

    @Test func originalMomentumAndEnergy() throws {
        let law: any HydraulicInertanceEvaluating = try HydraulicInertance(inertance: 5)
        var work = try HydraulicFixture.work()
        let r = try law.evaluate(volumeFlow: 2, flowAcceleration: 3, work: &work)
        #expect(r.pressureDifference == 15 && r.storedEnergy == 10 && r.storagePower == 30)
        #expect(r.dissipatedPower == 0)
        HydraulicFixture.balanced(r)
    }
    @Test func reverseAndDecelerationReturnEnergy() throws {
        let law = try HydraulicInertance(inertance: 5)
        var work = try HydraulicFixture.work()
        for pair in [(2.0, -3.0), (-2.0, 3.0)] {
            let r = try law.evaluate(volumeFlow: pair.0, flowAcceleration: pair.1, work: &work)
            #expect(r.storagePower == -30 && r.storedEnergy == 10)
            HydraulicFixture.balanced(r)
        }
    }
    @Test func zeroFlowAndConstantFlow() throws {
        let law = try HydraulicInertance(inertance: 5)
        var work = try HydraulicFixture.work()
        #expect(try law.evaluate(volumeFlow: 0, flowAcceleration: 2, work: &work).storedEnergy == 0)
        let r = try law.evaluate(volumeFlow: 2, flowAcceleration: 0, work: &work)
        #expect(r.pressureDifference == 0 && r.storedEnergy == 10)
    }
    @Test func originalEnergyGradientRefinement() throws {
        let law = try HydraulicInertance(inertance: 5)
        var work = try HydraulicFixture.work()
        for h in [1e-6, 5e-7] {
            let plus = try law.evaluate(volumeFlow: 2+h, flowAcceleration: 0, work: &work)
            let minus = try law.evaluate(volumeFlow: 2-h, flowAcceleration: 0, work: &work)
            #expect(HydraulicFixture.near((plus.storedEnergy-minus.storedEnergy)/(2*h), 10, absolute: 1e-8, relative: 1e-6))
        }
    }
    @Test func malformedParametersAndQuery() throws {
        for x in [0.0, -1, .nan, .infinity] { #expect(throws: ActuationError.invalidLaw) { try HydraulicInertance(inertance: x) } }
        let law = try HydraulicInertance(inertance: 1)
        var work = try HydraulicFixture.work()
        #expect(throws: ActuationError.invalidInput) { try law.evaluate(volumeFlow: .nan, flowAcceleration: 0, work: &work) }
        #expect(throws: ActuationError.invalidInput) { try law.evaluate(volumeFlow: 0, flowAcceleration: .infinity, work: &work) }
    }
    @Test func overflowRefuses() throws {
        let law = try HydraulicInertance(inertance: 1e308)
        var work = try HydraulicFixture.work()
        #expect(throws: ActuationError.nonfiniteResult) { try law.evaluate(volumeFlow: 2, flowAcceleration: 0, work: &work) }
    }
}

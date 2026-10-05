import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct HydraulicCheckValveTests {

    @Test func originalCrackingPressureFixture() throws {
        let law: any HydraulicResistanceEvaluating = try HydraulicCheckValve(conductance: 0.002, crackingPressure: 50)
        var work = try HydraulicFixture.work()
        let r = try law.evaluate(pressureDifference: 75, work: &work)
        #expect(r.volumeFlow == 0.05 && r.dissipatedPower == 3.75)
        HydraulicFixture.balanced(r)
    }
    @Test func closedThresholdAndReverseFlow() throws {
        let law = try HydraulicCheckValve(conductance: 2, crackingPressure: 10)
        var work = try HydraulicFixture.work()
        for p in [-1e100, 0, 9, 10] {
            let r = try law.evaluate(pressureDifference: p, work: &work)
            #expect(r.volumeFlow == 0 && r.dissipatedPower == 0)
        }
    }
    @Test func adjacentRepresentableOpening() throws {
        let law = try HydraulicCheckValve(conductance: 1, crackingPressure: 1)
        var work = try HydraulicFixture.work()
        let r = try law.evaluate(pressureDifference: Double(1).nextUp, work: &work)
        #expect(r.volumeFlow > 0 && r.dissipatedPower > 0)
    }
    @Test func zeroCrackIdealDiode() throws {
        let law = try HydraulicCheckValve(conductance: 2, crackingPressure: 0)
        var work = try HydraulicFixture.work()
        #expect(try law.evaluate(pressureDifference: 3, work: &work).volumeFlow == 6)
        #expect(try law.evaluate(pressureDifference: -3, work: &work).volumeFlow == 0)
    }
    @Test func malformedParametersAndQuery() throws {
        #expect(throws: ActuationError.invalidLaw) { try HydraulicCheckValve(conductance: 0, crackingPressure: 0) }
        #expect(throws: ActuationError.invalidLaw) { try HydraulicCheckValve(conductance: 1, crackingPressure: -1) }
        #expect(throws: ActuationError.invalidLaw) { try HydraulicCheckValve(conductance: .nan, crackingPressure: 0) }
        let law = try HydraulicCheckValve(conductance: 1, crackingPressure: 0)
        var work = try HydraulicFixture.work()
        #expect(throws: ActuationError.invalidInput) { try law.evaluate(pressureDifference: .nan, work: &work) }
    }
    @Test func overflowRefusesWithoutLeakFallback() throws {
        let law = try HydraulicCheckValve(conductance: 1e308, crackingPressure: 0)
        var work = try HydraulicFixture.work()
        #expect(throws: ActuationError.nonfiniteResult) { try law.evaluate(pressureDifference: 3, work: &work) }
    }
}

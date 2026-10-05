import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct HydraulicSupplierTests {
    @Test func capacityRefusedBeforeScalarArithmetic() throws {
        let law = try LaminarHydraulicResistance(resistance: 1)
        var work = try HydraulicFixture.work(scalars: 15)
        #expect(throws: ActuationError.capacityExceeded) { try law.evaluate(pressureDifference: 2, work: &work) }
        #expect(work.peakScalars == 0 && work.used == 0)
        var cylinderWork = try HydraulicFixture.work(scalars: 31)
        #expect(throws: ActuationError.capacityExceeded) { try HydraulicFixture.cylinderSample(HydraulicFixture.cylinder(), work: &cylinderWork) }
        #expect(cylinderWork.peakScalars == 0)
    }
    @Test func failedWorkRetainsOriginalSupplierLedger() throws {
        let law = try HydraulicInertance(inertance: 1)
        var work = try HydraulicFixture.work(operations: 31)
        #expect(throws: ActuationError.workExhausted) { try law.evaluate(volumeFlow: 1, flowAcceleration: 2, work: &work) }
        #expect(work.used == 0 && work.peakScalars == 16)
    }
    @Test func actualCancellationAndNoStateMutation() throws {
        let law = try LinearHydraulicCompliance(compliance: 1)
        var work = try HydraulicFixture.work(cancelled: true)
        #expect(throws: ActuationError.cancelled) { try law.evaluate(volumeDisplacement: 1, volumeFlow: 2, work: &work) }
        #expect(work.used == 0 && work.peakScalars == 0)
        var active = try HydraulicFixture.work()
        #expect(try law.evaluate(volumeDisplacement: 1, volumeFlow: 2, work: &active).fluidPower == 2)
    }
    @Test func originalPrechargedLedgerIsNotReset() throws {
        var work = try HydraulicFixture.work(operations: 33)
        try work.charge(1)
        let law = try HydraulicCheckValve(conductance: 1, crackingPressure: 0)
        let first = try law.evaluate(pressureDifference: 2, work: &work)
        #expect(work.used == 33 && first.dissipatedPower == 4)
        #expect(throws: ActuationError.workExhausted) { try law.evaluate(pressureDifference: 2, work: &work) }
        #expect(work.used == 33)
    }
}

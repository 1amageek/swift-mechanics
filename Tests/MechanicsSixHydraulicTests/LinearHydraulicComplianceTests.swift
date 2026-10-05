import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct LinearHydraulicComplianceTests {

    @Test func originalPressureAndStoredEnergy() throws {
        let law: any HydraulicComplianceEvaluating = try LinearHydraulicCompliance(compliance: 0.5)
        var work = try HydraulicFixture.work()
        let r = try law.evaluate(volumeDisplacement: 2, volumeFlow: 3, work: &work)
        #expect(r.pressureDifference == 4 && r.storedEnergy == 4 && r.storagePower == 12)
        HydraulicFixture.balanced(r)
    }
    @Test func signedGaugeStorageAndRelease() throws {
        let law = try LinearHydraulicCompliance(compliance: 0.5)
        var work = try HydraulicFixture.work()
        let r = try law.evaluate(volumeDisplacement: -2, volumeFlow: 3, work: &work)
        #expect(r.pressureDifference == -4 && r.storedEnergy == 4 && r.storagePower == -12)
        HydraulicFixture.balanced(r)
    }
    @Test func referenceAndHeldVolume() throws {
        let law = try LinearHydraulicCompliance(compliance: 0.5)
        var work = try HydraulicFixture.work()
        #expect(try law.evaluate(volumeDisplacement: 0, volumeFlow: 3, work: &work).storagePower == 0)
        let r = try law.evaluate(volumeDisplacement: 2, volumeFlow: 0, work: &work)
        #expect(r.storedEnergy == 4 && r.storagePower == 0)
    }
    @Test func originalEnergyGradientRefinement() throws {
        let law = try LinearHydraulicCompliance(compliance: 0.5)
        var work = try HydraulicFixture.work()
        for h in [1e-6, 5e-7] {
            let plus = try law.evaluate(volumeDisplacement: 2+h, volumeFlow: 0, work: &work)
            let minus = try law.evaluate(volumeDisplacement: 2-h, volumeFlow: 0, work: &work)
            #expect(HydraulicFixture.near((plus.storedEnergy-minus.storedEnergy)/(2*h), 4, absolute: 1e-8, relative: 1e-6))
        }
    }
    @Test func malformedParametersAndQuery() throws {
        for x in [0.0, -1, .nan, .infinity] { #expect(throws: ActuationError.invalidLaw) { try LinearHydraulicCompliance(compliance: x) } }
        let law = try LinearHydraulicCompliance(compliance: 1)
        var work = try HydraulicFixture.work()
        #expect(throws: ActuationError.invalidInput) { try law.evaluate(volumeDisplacement: .nan, volumeFlow: 0, work: &work) }
        #expect(throws: ActuationError.invalidInput) { try law.evaluate(volumeDisplacement: 0, volumeFlow: .infinity, work: &work) }
    }
    @Test func overflowRefuses() throws {
        let law = try LinearHydraulicCompliance(compliance: Double.leastNonzeroMagnitude)
        var work = try HydraulicFixture.work()
        #expect(throws: ActuationError.nonfiniteResult) { try law.evaluate(volumeDisplacement: 1, volumeFlow: 1, work: &work) }
    }
}

import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct ElectrostaticCombDriveTests {
    func make() throws -> ElectrostaticCombDrive { try ElectrostaticCombDrive(referenceCapacitance: 4, capacitanceGradient: 2, minimumPosition: -1, maximumPosition: 1, leakageConductance: 0.5) }
    @Test func originalEnergyAndConjugatePorts() throws {
        let law: any EnergyTransducerEvaluating = try make()
        var work = try TransducerFixture.work()
        let r = try law.evaluate(position: 0, electricalState: 4, work: &work)
        TransducerFixture.original(r, energy: 2, force: 1, effort: 1, mechanical: -1, coupling: 0.5, electrical: 0.25)
        #expect(r.electricalCoordinate == .charge)
    }
    @Test func allEnergyGradientsAndReciprocalTangents() throws {
        try TransducerFixture.gradient(make(), q: 0, s: 4)
    }
    @Test func originalPowerAndActualAffineMechanicalPort() throws {
        try TransducerFixture.powerAndOriginalMechanicalPort(make(), q: 0, s: 4)
    }
    @Test func selectedPhysicalBranches() throws {

        let law = try make()
        var work = try TransducerFixture.work()
        #expect(try law.evaluate(position: -1, electricalState: 4, work: &work).mechanicalEffort == 4)
        #expect(throws: ActuationError.outsideDomain) { try law.evaluate(position: Double(1).nextUp, electricalState: 4, work: &work) }
        let reversed = try ElectrostaticCombDrive(referenceCapacitance: 4, capacitanceGradient: -2, minimumPosition: -1, maximumPosition: 1)
        #expect(try reversed.evaluate(position: 0, electricalState: 4, work: &work).mechanicalEffort == -1)
    }
    @Test func malformedParameterRefusal() throws {
        #expect(throws: ActuationError.invalidLaw) { try ElectrostaticCombDrive(referenceCapacitance: 2, capacitanceGradient: 2, minimumPosition: -1, maximumPosition: 1) }
    }
    @Test func nonfiniteOverflowAndPreservedSample() throws {
        try TransducerFixture.queryRefusals(make(), q: 0, s: 4)
    }
}

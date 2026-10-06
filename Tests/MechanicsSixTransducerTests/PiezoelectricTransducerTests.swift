import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct PiezoelectricTransducerTests {
    func make() throws -> PiezoelectricTransducer { try PiezoelectricTransducer(capacitance: 2, chargeDisplacementCoefficient: 3, stiffness: 4, leakageConductance: 0.5) }
    @Test func originalEnergyAndConjugatePorts() throws {
        let law: any EnergyTransducerEvaluating = try make()
        var work = try TransducerFixture.work()
        let r = try law.evaluate(position: 0.2, electricalState: 1.4, work: &work)
        TransducerFixture.original(r, energy: 0.24, force: 0.4, effort: 0.4, mechanical: -8.5, coupling: 1.5, electrical: 0.5)
        #expect(r.electricalCoordinate == .charge)
    }
    @Test func allEnergyGradientsAndReciprocalTangents() throws {
        try TransducerFixture.gradient(make(), q: 0.2, s: 1.4)
    }
    @Test func originalPowerAndActualAffineMechanicalPort() throws {
        try TransducerFixture.powerAndOriginalMechanicalPort(make(), q: 0.2, s: 1.4)
    }
    @Test func selectedPhysicalBranches() throws {

        let law = try make()
        var work = try TransducerFixture.work()
        let zero = try law.evaluate(position: 0.2, electricalState: 0.6, work: &work)
        #expect(TransducerFixture.near(zero.electricalEffort, 0) && TransducerFixture.near(zero.mechanicalEffort, -0.8))
        let reverse = try PiezoelectricTransducer(capacitance: 2, chargeDisplacementCoefficient: -3, stiffness: 4)
        let reversed = try reverse.evaluate(position: -0.2, electricalState: 1.4, work: &work)
        #expect(TransducerFixture.near(reversed.mechanicalEffort, -0.4))
    }
    @Test func malformedParameterRefusal() throws {
        #expect(throws: ActuationError.invalidLaw) { try PiezoelectricTransducer(capacitance: 2, chargeDisplacementCoefficient: 3, stiffness: -1) }
    }
    @Test func nonfiniteOverflowAndPreservedSample() throws {
        try TransducerFixture.queryRefusals(make(), q: 0.2, s: 1.4)
    }
}

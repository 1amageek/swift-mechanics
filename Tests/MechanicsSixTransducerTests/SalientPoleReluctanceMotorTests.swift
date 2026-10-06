import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct SalientPoleReluctanceMotorTests {
    func make() throws -> SalientPoleReluctanceMotor { try SalientPoleReluctanceMotor(meanInductance: 4, harmonicInductance: 2, harmonicOrder: 2, resistance: 0.5) }
    @Test func originalEnergyAndConjugatePorts() throws {
        let law: any EnergyTransducerEvaluating = try make()
        var work = try TransducerFixture.work()
        let r = try law.evaluate(position: Double.pi/4, electricalState: 4, work: &work)
        TransducerFixture.original(r, energy: 2, force: -2, effort: 1, mechanical: -4, coupling: -1, electrical: 0.25)
        #expect(r.electricalCoordinate == .fluxLinkage)
    }
    @Test func allEnergyGradientsAndReciprocalTangents() throws {
        try TransducerFixture.gradient(make(), q: Double.pi/4, s: 4)
    }
    @Test func originalPowerAndActualAffineMechanicalPort() throws {
        try TransducerFixture.powerAndOriginalMechanicalPort(make(), q: Double.pi/4, s: 4)
    }
    @Test func selectedPhysicalBranches() throws {

        let law = try make()
        var work = try TransducerFixture.work()
        let reversed = try law.evaluate(position: -Double.pi/4, electricalState: 4, work: &work)
        #expect(TransducerFixture.near(reversed.mechanicalEffort, 2))
        let manyTurns = try law.evaluate(position: 12*Double.pi+Double.pi/4, electricalState: 4, work: &work)
        #expect(TransducerFixture.near(manyTurns.mechanicalEffort, -2))
        #expect(manyTurns.position > 12*Double.pi && manyTurns.mechanicalCoordinate == .rotation)
        let isotropic = try SalientPoleReluctanceMotor(meanInductance: 4, harmonicInductance: 0, harmonicOrder: 2)
        #expect(try isotropic.evaluate(position: 0.3, electricalState: 4, work: &work).mechanicalEffort == 0)
    }
    @Test func malformedParameterRefusal() throws {
        #expect(throws: ActuationError.invalidLaw) { try SalientPoleReluctanceMotor(meanInductance: 2, harmonicInductance: 2, harmonicOrder: 0) }
    }
    @Test func nonfiniteOverflowAndPreservedSample() throws {
        try TransducerFixture.queryRefusals(make(), q: Double.pi/4, s: 4)
    }
}

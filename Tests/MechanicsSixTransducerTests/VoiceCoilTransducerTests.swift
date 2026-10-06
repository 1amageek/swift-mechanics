import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct VoiceCoilTransducerTests {
    func make() throws -> VoiceCoilTransducer { try VoiceCoilTransducer(inductance: 2, forceConstant: 3, resistance: 0.5) }
    @Test func originalEnergyAndConjugatePorts() throws {
        let law: any EnergyTransducerEvaluating = try make()
        var work = try TransducerFixture.work()
        let r = try law.evaluate(position: 0.2, electricalState: 1.4, work: &work)
        TransducerFixture.original(r, energy: 0.16, force: 1.2, effort: 0.4, mechanical: -4.5, coupling: 1.5, electrical: 0.5)
        #expect(r.electricalCoordinate == .fluxLinkage)
    }
    @Test func allEnergyGradientsAndReciprocalTangents() throws {
        try TransducerFixture.gradient(make(), q: 0.2, s: 1.4)
    }
    @Test func originalPowerAndActualAffineMechanicalPort() throws {
        try TransducerFixture.powerAndOriginalMechanicalPort(make(), q: 0.2, s: 1.4)
    }
    @Test func selectedPhysicalBranches() throws {

        let reverse = try VoiceCoilTransducer(inductance: 2, forceConstant: -3)
        var work = try TransducerFixture.work()
        let r = try reverse.evaluate(position: -0.2, electricalState: 1.4, work: &work)
        #expect(TransducerFixture.near(r.mechanicalEffort, -1.2))
        let law = try make(), sample = try law.evaluate(position: 0.2, electricalState: 1.4, work: &work)
        // Holding current includes the motional flux rate k*v.
        let p = try sample.power(mechanicalRate: 2, electricalRate: 6, work: &work)
        #expect(TransducerFixture.near(p.storagePower, 0) && TransducerFixture.near(p.driveEffort, 6.2))
    }
    @Test func malformedParameterRefusal() throws {
        #expect(throws: ActuationError.invalidLaw) { try VoiceCoilTransducer(inductance: 0, forceConstant: 3) }
    }
    @Test func nonfiniteOverflowAndPreservedSample() throws {
        try TransducerFixture.queryRefusals(make(), q: 0.2, s: 1.4)
    }
}

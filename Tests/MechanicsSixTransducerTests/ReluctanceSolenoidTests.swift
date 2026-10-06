import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct ReluctanceSolenoidTests {
    func make() throws -> ReluctanceSolenoid { try ReluctanceSolenoid(inductanceLengthProduct: 2, referenceGap: 3, minimumGap: 0.5, resistance: 0.5) }
    @Test func originalEnergyAndConjugatePorts() throws {
        let law: any EnergyTransducerEvaluating = try make()
        var work = try TransducerFixture.work()
        let r = try law.evaluate(position: 1, electricalState: 2, work: &work)
        TransducerFixture.original(r, energy: 2, force: 1, effort: 2, mechanical: 0, coupling: 1, electrical: 1)
        #expect(r.electricalCoordinate == .fluxLinkage)
    }
    @Test func allEnergyGradientsAndReciprocalTangents() throws {
        try TransducerFixture.gradient(make(), q: 1, s: 2)
    }
    @Test func originalPowerAndActualAffineMechanicalPort() throws {
        try TransducerFixture.powerAndOriginalMechanicalPort(make(), q: 1, s: 2)
    }
    @Test func selectedPhysicalBranches() throws {

        let law = try make()
        var work = try TransducerFixture.work()
        let boundary = try law.evaluate(position: 2.5, electricalState: -2, work: &work)
        #expect(boundary.mechanicalEffort == 1 && boundary.electricalEffort == -0.5)
        #expect(throws: ActuationError.outsideDomain) { try law.evaluate(position: Double(2.5).nextUp, electricalState: 2, work: &work) }
        #expect(try law.evaluate(position: 1, electricalState: 0, work: &work).mechanicalEffort == 0)
    }
    @Test func malformedParameterRefusal() throws {
        #expect(throws: ActuationError.invalidLaw) { try ReluctanceSolenoid(inductanceLengthProduct: 2, referenceGap: 1, minimumGap: 1) }
    }
    @Test func nonfiniteOverflowAndPreservedSample() throws {
        try TransducerFixture.queryRefusals(make(), q: 1, s: 2)
    }
}

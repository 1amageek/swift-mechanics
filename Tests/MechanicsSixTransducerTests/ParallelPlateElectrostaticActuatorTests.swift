import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct ParallelPlateElectrostaticActuatorTests {
    func make() throws -> ParallelPlateElectrostaticActuator { try ParallelPlateElectrostaticActuator(permittivity: 1, area: 2, referenceGap: 3, minimumGap: 0.5, leakageConductance: 0.5) }
    @Test func originalEnergyAndConjugatePorts() throws {
        let law: any EnergyTransducerEvaluating = try make()
        var work = try TransducerFixture.work()
        let r = try law.evaluate(position: 1, electricalState: 2, work: &work)
        TransducerFixture.original(r, energy: 2, force: 1, effort: 2, mechanical: 0, coupling: 1, electrical: 1)
        #expect(r.electricalCoordinate == .charge)
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
        let oppositeCharge = try law.evaluate(position: 1, electricalState: -2, work: &work)
        #expect(oppositeCharge.mechanicalEffort == 1 && oppositeCharge.electricalEffort == -2)
        #expect(try law.evaluate(position: 2.5, electricalState: 2, work: &work).electricalEffort == 0.5)
        #expect(throws: ActuationError.outsideDomain) { try law.evaluate(position: Double(2.5).nextUp, electricalState: 2, work: &work) }
        #expect(throws: ActuationError.invalidLaw) { try ParallelPlateElectrostaticActuator(permittivity: 1e308, area: 1e308, referenceGap: 3, minimumGap: 1) }
    }
    @Test func malformedParameterRefusal() throws {
        #expect(throws: ActuationError.invalidLaw) { try ParallelPlateElectrostaticActuator(permittivity: 0, area: 2, referenceGap: 3, minimumGap: 0.5) }
    }
    @Test func nonfiniteOverflowAndPreservedSample() throws {
        try TransducerFixture.queryRefusals(make(), q: 1, s: 2)
    }
}

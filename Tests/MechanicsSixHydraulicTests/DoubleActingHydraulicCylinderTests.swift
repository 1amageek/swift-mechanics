import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct DoubleActingHydraulicCylinderTests {

    @Test func originalTwoChamberPressureAndPower() throws {
        let law: any HydraulicCylinderEvaluating = try HydraulicFixture.cylinder()
        var work = try HydraulicFixture.work()
        let r = try HydraulicFixture.cylinderSample(law, work: &work)
        #expect(HydraulicFixture.near(r.firstPressureRate, 4) && HydraulicFixture.near(r.secondPressureRate, 8))
        #expect(HydraulicFixture.near(r.force, 0.76) && HydraulicFixture.near(r.leakageFlow, 0.0006))
        #expect(HydraulicFixture.near(r.sourcePower, 0.26) && HydraulicFixture.near(r.mechanicalPower, 0.152))
        #expect(HydraulicFixture.near(r.storedEnergy, 0.58) && HydraulicFixture.near(r.storagePower, 0.072))
        #expect(HydraulicFixture.near(r.dissipatedPower, 0.036) && HydraulicFixture.near(r.balanceResidual, 0))
    }
    @Test func reverseLeakageAndReservoirConvention() throws {
        let law = try HydraulicFixture.cylinder()
        var work = try HydraulicFixture.work()
        let r = try HydraulicFixture.cylinderSample(law, velocity: -0.2, p1: 40, p2: 100, q1: 0, q2: 0, work: &work)
        #expect(HydraulicFixture.near(r.leakageFlow, -0.0006))
        #expect(HydraulicFixture.near(r.dissipatedPower, 0.036) && HydraulicFixture.near(r.balanceResidual, 0))
        let zero = try HydraulicFixture.cylinderSample(law, p1: 0, p2: 0, work: &work)
        #expect(zero.force == 0 && zero.storedEnergy == 0)
    }
    @Test func matchedFlowsHoldPressureWithoutLeak() throws {
        let law = try HydraulicFixture.cylinder(leakage: 0)
        var work = try HydraulicFixture.work()
        let r = try HydraulicFixture.cylinderSample(law, q1: 0.002, q2: -0.0012, work: &work)
        #expect(HydraulicFixture.near(r.firstPressureRate, 0) && HydraulicFixture.near(r.secondPressureRate, 0))
        #expect(r.dissipatedPower == 0 && HydraulicFixture.near(r.sourcePower, r.mechanicalPower))
    }
    @Test func independentStorageGradientRefinement() throws {
        let law = try HydraulicFixture.cylinder()
        var work = try HydraulicFixture.work()
        for h in [1e-6, 5e-7] {
            let plus = try HydraulicFixture.cylinderSample(law, p1: 100+h, work: &work)
            let minus = try HydraulicFixture.cylinderSample(law, p1: 100-h, work: &work)
            #expect(HydraulicFixture.near((plus.storedEnergy-minus.storedEnergy)/(2*h), 0.01, absolute: 1e-8, relative: 1e-6))
        }
    }
    @Test func actualPublishedMechanicalPortCoupling() throws {
        let law = try HydraulicFixture.cylinder()
        var work = try HydraulicFixture.work()
        let r = try HydraulicFixture.cylinderSample(law, work: &work)
        let model = ModelStamp(identity: "hydraulic", revision: 1)
        let frame = try EntityID(kind: .frame, key: "world")
        let row = try AffineTransmission(model: model, frame: frame, outputCoordinate: .translation,
            inputCoordinates: [.translation], gradient: [1], prescribedRate: 0, work: &work)
        var numerical = NumericalWork(budget: try NumericalBudget(scalarStorage: 4, arithmeticOperations: 100, iterations: 0))
        let service: any ActuationTransmitting = ReferenceActuationTransmitter(mapper: LoadMapper())
        let response = try service.affine(row, model: model, frame: frame, effort: r.force, rate: [0.2],
            tolerance: NumericalTolerance(absolute: 1e-10, relative: 1e-10), work: &work, numerical: &numerical)
        #expect(HydraulicFixture.near(response.efforts[0], 0.76))
        #expect(HydraulicFixture.near(response.actualPower, r.mechanicalPower))
    }
    @Test func physicalApproximationAndParameterAdmission() throws {
        #expect(throws: ActuationError.invalidLaw) { try HydraulicFixture.cylinder(leakage: -1) }
        let law = try HydraulicFixture.cylinder()
        var work = try HydraulicFixture.work()
        #expect(throws: ActuationError.outsideDomain) { try HydraulicFixture.cylinderSample(law, stroke: 2, work: &work) }
        #expect(throws: ActuationError.outsideDomain) { try HydraulicFixture.cylinderSample(law, p1: -1, work: &work) }
        #expect(throws: ActuationError.outsideDomain) { try HydraulicFixture.cylinderSample(law, p1: 201, work: &work) }
        #expect(throws: ActuationError.outsideDomain) { try HydraulicFixture.cylinderSample(law, q2: 2, work: &work) }
        #expect(throws: ActuationError.invalidInput) { try HydraulicFixture.cylinderSample(law, velocity: .nan, work: &work) }
    }
    @Test func overflowRefusesAndImmutableSampleRetained() throws {
        let law = try HydraulicFixture.cylinder()
        var work = try HydraulicFixture.work()
        let before = try HydraulicFixture.cylinderSample(law, work: &work)
        #expect(throws: ActuationError.nonfiniteResult) { try HydraulicFixture.cylinderSample(law, velocity: 1e308, work: &work) }
        #expect(try HydraulicFixture.cylinderSample(law, work: &work) == before)
    }
}

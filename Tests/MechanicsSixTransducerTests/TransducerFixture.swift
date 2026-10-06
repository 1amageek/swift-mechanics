import SwiftMechanics
import Testing

struct TransducerFixture {
    static func work(scalars: Int = 32, operations: Int = 20000, cancelled: Bool = false) throws -> ActuationWork {
        ActuationWork(budget: try ActuationBudget(maximumWork: operations, maximumScalars: scalars,
            maximumBytes: 0, maximumBindings: 0, maximumMetadataBytes: 128, isCancelled: { cancelled }))
    }
    static func near(_ a: Double, _ b: Double, absolute: Double = 1e-10, relative: Double = 1e-9) -> Bool {
        abs(a-b) <= absolute + relative * max(abs(a), abs(b))
    }
    static func original(_ r: ElectromechanicalEnergySample, energy: Double, force: Double, effort: Double,
                         mechanical: Double, coupling: Double, electrical: Double) {
        #expect(near(r.storedEnergy, energy)); #expect(near(r.mechanicalEffort, force))
        #expect(near(r.electricalEffort, effort)); #expect(near(r.mechanicalTangent, mechanical))
        #expect(near(r.coupling, coupling)); #expect(near(r.electricalTangent, electrical))
    }
    static func gradient(_ law: any EnergyTransducerEvaluating, q: Double, s: Double) throws {
        var work = try work()
        let original = try law.evaluate(position: q, electricalState: s, work: &work)
        for h in [1e-5, 5e-6] {
            let qp = try law.evaluate(position: q+h, electricalState: s, work: &work)
            let qm = try law.evaluate(position: q-h, electricalState: s, work: &work)
            let sp = try law.evaluate(position: q, electricalState: s+h, work: &work)
            let sm = try law.evaluate(position: q, electricalState: s-h, work: &work)
            #expect(near(-(qp.storedEnergy-qm.storedEnergy)/(2*h), original.mechanicalEffort, absolute: 1e-7, relative: 2e-5))
            #expect(near((sp.storedEnergy-sm.storedEnergy)/(2*h), original.electricalEffort, absolute: 1e-7, relative: 2e-5))
            #expect(near((qp.mechanicalEffort-qm.mechanicalEffort)/(2*h), original.mechanicalTangent, absolute: 1e-7, relative: 2e-5))
            #expect(near((sp.electricalEffort-sm.electricalEffort)/(2*h), original.electricalTangent, absolute: 1e-7, relative: 2e-5))
            #expect(near((sp.mechanicalEffort-sm.mechanicalEffort)/(2*h), original.coupling, absolute: 1e-7, relative: 2e-5))
            #expect(near((qp.electricalEffort-qm.electricalEffort)/(2*h), -original.coupling, absolute: 1e-7, relative: 2e-5))
        }
    }
    static func powerAndOriginalMechanicalPort(_ law: any EnergyTransducerEvaluating, q: Double, s: Double) throws {
        var work = try work()
        let r = try law.evaluate(position: q, electricalState: s, work: &work)
        for sign in [-1.0, 1.0] {
            let velocity = 0.7*sign, stateRate = -0.3*sign
            let power = try r.power(mechanicalRate: velocity, electricalRate: stateRate, work: &work)
            #expect(near(power.sourcePower, power.mechanicalPower + power.storagePower + power.physicalLoss))
            #expect(near(power.balanceResidual, 0) && power.physicalLoss >= 0)
            for h in [1e-5, 5e-6] {
                let plus = try law.evaluate(position: q+velocity*h, electricalState: s+stateRate*h, work: &work)
                let minus = try law.evaluate(position: q-velocity*h, electricalState: s-stateRate*h, work: &work)
                #expect(near((plus.storedEnergy-minus.storedEnergy)/(2*h), power.storagePower, absolute: 1e-7, relative: 2e-5))
            }
        }
        let model = ModelStamp(identity: "transducer", revision: 1), frame = try EntityID(kind: .frame, key: "world")
        let row = try AffineTransmission(model: model, frame: frame, outputCoordinate: r.mechanicalCoordinate,
            inputCoordinates: [r.mechanicalCoordinate], gradient: [1], prescribedRate: 0, work: &work)
        var numerical = NumericalWork(budget: try NumericalBudget(scalarStorage: 4, arithmeticOperations: 100, iterations: 0))
        let service: any ActuationTransmitting = ReferenceActuationTransmitter(mapper: LoadMapper())
        let output = try service.affine(row, model: model, frame: frame, effort: r.mechanicalEffort, rate: [0.7],
            tolerance: NumericalTolerance(absolute: 1e-10, relative: 1e-10), work: &work, numerical: &numerical)
        #expect(near(output.efforts[0], r.mechanicalEffort))
        #expect(near(output.actualPower, try r.power(mechanicalRate: 0.7, electricalRate: 0, work: &work).mechanicalPower))
    }
    static func queryRefusals(_ law: any EnergyTransducerEvaluating, q: Double, s: Double) throws {
        var work = try work()
        let before = try law.evaluate(position: q, electricalState: s, work: &work)
        #expect(throws: ActuationError.invalidInput) { try law.evaluate(position: .nan, electricalState: s, work: &work) }
        #expect(throws: ActuationError.invalidInput) { try law.evaluate(position: q, electricalState: .infinity, work: &work) }
        #expect(throws: ActuationError.nonfiniteResult) { try law.evaluate(position: q, electricalState: 1e308, work: &work) }
        #expect(try law.evaluate(position: q, electricalState: s, work: &work) == before)
    }
}

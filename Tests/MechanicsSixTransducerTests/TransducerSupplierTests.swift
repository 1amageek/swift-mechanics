import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct TransducerSupplierTests {
    @Test func actualCapacityAndWorkRefusalBeforeOutput() throws {
        let law = try VoiceCoilTransducer(inductance: 2, forceConstant: 3)
        var limited = try TransducerFixture.work(scalars: 23)
        #expect(throws: ActuationError.capacityExceeded) { try law.evaluate(position: 0, electricalState: 1, work: &limited) }
        #expect(limited.peakScalars == 0 && limited.used == 0)
        var exhausted = try TransducerFixture.work(operations: 63)
        #expect(throws: ActuationError.workExhausted) { try law.evaluate(position: 0, electricalState: 1, work: &exhausted) }
        #expect(exhausted.peakScalars == 24 && exhausted.used == 0)
    }
    @Test func actualCancellationAndOriginalPowerCapacity() throws {
        let law = try VoiceCoilTransducer(inductance: 2, forceConstant: 3)
        var cancelled = try TransducerFixture.work(cancelled: true)
        #expect(throws: ActuationError.cancelled) { try law.evaluate(position: 0, electricalState: 1, work: &cancelled) }
        #expect(cancelled.used == 0 && cancelled.peakScalars == 0)
        var active = try TransducerFixture.work()
        let sample = try law.evaluate(position: 0, electricalState: 1, work: &active)
        var limited = try TransducerFixture.work(scalars: 15)
        #expect(throws: ActuationError.capacityExceeded) { try sample.power(mechanicalRate: 0, electricalRate: 0, work: &limited) }
        #expect(throws: ActuationError.cancelled) { try sample.power(mechanicalRate: 0, electricalRate: 0, work: &cancelled) }
    }
    @Test func invalidPowerRatesAndOverflowAreRefused() throws {
        let law = try VoiceCoilTransducer(inductance: 2, forceConstant: 3)
        var work = try TransducerFixture.work()
        let sample = try law.evaluate(position: 0, electricalState: 4, work: &work)
        #expect(throws: ActuationError.invalidInput) { try sample.power(mechanicalRate: .nan, electricalRate: 0, work: &work) }
        #expect(throws: ActuationError.invalidInput) { try sample.power(mechanicalRate: 0, electricalRate: .infinity, work: &work) }
        #expect(throws: ActuationError.nonfiniteResult) { try sample.power(mechanicalRate: 1e308, electricalRate: 0, work: &work) }
        #expect(try law.evaluate(position: 0, electricalState: 4, work: &work) == sample)
    }
    @Test func prechargedOriginalLedgerIsPreserved() throws {
        let law = try VoiceCoilTransducer(inductance: 2, forceConstant: 3)
        var work = try TransducerFixture.work(operations: 65)
        try work.charge(1)
        let sample = try law.evaluate(position: 0, electricalState: 1, work: &work)
        #expect(work.used == 65 && sample.storedEnergy == 0.25)
        #expect(throws: ActuationError.workExhausted) { try law.evaluate(position: 0, electricalState: 1, work: &work) }
        #expect(work.used == 65)
    }
}

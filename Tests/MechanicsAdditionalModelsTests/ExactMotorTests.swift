import Testing
import SwiftMechanics
import Foundation

@Suite struct ExactMotorTests {
    let service: any ExactMotorEvolving = ExactDCMotorEvolution()
    func parameters(_ resistance: Double = 4) throws -> ExactMotorParameters {
        try ExactMotorParameters(inductance: 2, resistance: resistance, reciprocalConstant: 0.5, damping: 0.1,
                                 maximumVoltage: 100, maximumCurrent: 100, maximumSpeed: 50)
    }
    @Test func heldInputSolutionAndIndependentEnergy() throws {
        var work = try AdditionalModelFixture.actuationWork()
        let p = try parameters(), old = try ExactMotorState(parameters: p, time: 0, current: 3)
        let r = try service.step(parameters: p, accepted: old, voltage: 10, speed: 2, timeStep: 0.4, work: &work)
        let eq = 2.25, delta = 0.75, decay = exp(-0.8)
        let integral = eq*0.4 + delta*(1-decay)/2
        let square = eq*eq*0.4 + 2*eq*delta*(1-decay)/2 + delta*delta*(1-exp(-1.6))/4
        #expect(AdditionalModelFixture.near(r.state.current, eq + delta*decay))
        #expect(AdditionalModelFixture.near(r.sourceWork, 10*integral))
        #expect(AdditionalModelFixture.near(r.copperLoss, 4*square))
        #expect(AdditionalModelFixture.near(r.meanTorque, 0.5*integral/0.4 - 0.2))
        #expect(AdditionalModelFixture.near(r.energyResidual, 0))
        #expect(AdditionalModelFixture.near(r.shaftWork, r.meanTorque*2*0.4))
        #expect(old.current == 3 && old.time == 0)
    }
    @Test func zeroResistanceAndSignChangingCurrent() throws {
        var work = try AdditionalModelFixture.actuationWork()
        let p = try parameters(0), old = try ExactMotorState(parameters: p, time: 0, current: -1)
        let r = try service.step(parameters: p, accepted: old, voltage: 8, speed: 0, timeStep: 0.5, work: &work)
        #expect(r.state.current == 1)
        #expect(AdditionalModelFixture.near(r.meanCurrent, 0))
        #expect(r.copperLoss == 0 && r.sourceWork == 0)
        #expect(AdditionalModelFixture.near(r.energyResidual, 0))
        let small = try parameters(1e-12), state = try ExactMotorState(parameters: small, time: 0, current: -1)
        let near = try service.step(parameters: small, accepted: state, voltage: 8, speed: 0, timeStep: 0.5, work: &work)
        #expect(AdditionalModelFixture.near(near.state.current, r.state.current))
        #expect(near.copperLoss > 0)
    }
    @Test func compositionAndRegeneration() throws {
        var work = try AdditionalModelFixture.actuationWork()
        let p = try parameters(), old = try ExactMotorState(parameters: p, time: 0, current: -2)
        let whole = try service.step(parameters: p, accepted: old, voltage: 0, speed: 10, timeStep: 0.5, work: &work)
        let a = try service.step(parameters: p, accepted: old, voltage: 0, speed: 10, timeStep: 0.2, work: &work)
        let b = try service.step(parameters: p, accepted: a.state, voltage: 0, speed: 10, timeStep: 0.3, work: &work)
        #expect(AdditionalModelFixture.near(whole.state.current, b.state.current))
        #expect(AdditionalModelFixture.near(whole.copperLoss, a.copperLoss+b.copperLoss))
        #expect(AdditionalModelFixture.near(whole.shaftWork, a.shaftWork+b.shaftWork))
        #expect(whole.shaftWork < 0)
        #expect(AdditionalModelFixture.near(whole.energyResidual, 0))
    }
    @Test func domainsHistoryAndCancellation() throws {
        let p = try parameters(), old = try ExactMotorState(parameters: p, time: 0, current: 0)
        var work = try AdditionalModelFixture.actuationWork()
        #expect(throws: ActuationError.outsideDomain) { try service.step(parameters: p, accepted: old, voltage: 101, speed: 0, timeStep: 1, work: &work) }
        #expect(throws: ActuationError.staleBinding) { try service.step(parameters: parameters(2), accepted: old, voltage: 1, speed: 0, timeStep: 1, work: &work) }
        var exhausted = try AdditionalModelFixture.actuationWork(maximumWork: 99)
        #expect(throws: ActuationError.workExhausted) { try service.step(parameters: p, accepted: old, voltage: 1, speed: 0, timeStep: 1, work: &exhausted) }
        var cancelled = try AdditionalModelFixture.actuationWork(cancelled: true)
        #expect(throws: ActuationError.cancelled) { try service.step(parameters: p, accepted: old, voltage: 1, speed: 0, timeStep: 1, work: &cancelled) }
        #expect(old.current == 0 && old.time == 0)
    }
}

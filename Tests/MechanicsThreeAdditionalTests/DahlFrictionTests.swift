import Testing
import SwiftMechanics
import Foundation

@Suite struct DahlFrictionTests {
    let service: any DahlFrictionEvolving = ExactDahlFrictionEvolution()
    func law() throws -> DahlFrictionLaw {
        try DahlFrictionLaw(stiffness: 100, limitingForce: 5, viscousCoefficient: 0.5, maximumSpeed: 10)
    }
    @Test func analyticRampAndIndependentDissipation() throws {
        let p = try law(), old = try DahlFrictionState(law: p, time: 0, deflection: 0)
        var work = try ThreeModelFixture.work()
        let r = try service.step(law: p, accepted: old, speed: 1, timeStep: 0.1, work: &work)
        let decay = exp(-2.0), ell = 0.05
        let squareIntegral = ell*ell*(0.1 - 2*(1-decay)/20 + (1-exp(-4.0))/40)
        #expect(ThreeModelFixture.near(r.state.deflection, ell*(1-decay)))
        #expect(ThreeModelFixture.near(r.endpointForce, -5*(1-decay)-0.5))
        #expect(ThreeModelFixture.near(r.dissipatedEnergy, 100*20*squareIntegral+0.05))
        #expect(ThreeModelFixture.near(r.energyResidual, 0))
        #expect(old.deflection == 0 && old.time == 0)
    }
    @Test func compositionAndVelocityReversal() throws {
        let p = try law(), old = try DahlFrictionState(law: p, time: 0, deflection: 0.03)
        var work = try ThreeModelFixture.work()
        let whole = try service.step(law: p, accepted: old, speed: -0.2, timeStep: 0.1, work: &work)
        let a = try service.step(law: p, accepted: old, speed: -0.2, timeStep: 0.04, work: &work)
        let b = try service.step(law: p, accepted: a.state, speed: -0.2, timeStep: 0.06, work: &work)
        #expect(ThreeModelFixture.near(whole.state.deflection, b.state.deflection))
        #expect(ThreeModelFixture.near(whole.frictionWork, a.frictionWork+b.frictionWork))
        #expect(ThreeModelFixture.near(whole.dissipatedEnergy, a.dissipatedEnergy+b.dissipatedEnergy))
        #expect(whole.frictionWork > 0 && whole.storageChange < 0)
        #expect(whole.dissipatedEnergy >= 0)
        #expect(ThreeModelFixture.near(whole.energyResidual, 0))
    }
    @Test func stationaryFrictionAndTinyMotion() throws {
        let p = try law(), old = try DahlFrictionState(law: p, time: 0, deflection: 0.02)
        var work = try ThreeModelFixture.work()
        let rest = try service.step(law: p, accepted: old, speed: 0, timeStep: 0.1, work: &work)
        #expect(rest.state.deflection == old.deflection && rest.state.time == 0.1)
        #expect(rest.endpointForce == -2 && rest.meanForce == -2)
        #expect(rest.frictionWork == 0 && rest.dissipatedEnergy == 0 && rest.storageChange == 0)
        let virgin = try DahlFrictionState(law: p, time: 0, deflection: 0)
        let tiny = try service.step(law: p, accepted: virgin, speed: 1, timeStep: 1e-12, work: &work)
        #expect(ThreeModelFixture.near(tiny.state.deflection, 1e-12, absolute: 1e-23))
        #expect(tiny.dissipatedEnergy > 0)
        #expect(ThreeModelFixture.near(tiny.energyResidual, 0, absolute: 1e-24))
    }
    @Test func historyLawAndFailureIsolation() throws {
        let p = try law(), old = try DahlFrictionState(law: p, time: 0, deflection: 0)
        var work = try ThreeModelFixture.work()
        let changed = try DahlFrictionLaw(stiffness: 101, limitingForce: 5, viscousCoefficient: 0.5, maximumSpeed: 10)
        #expect(throws: LoadError.providerChanged) { try service.step(law: changed, accepted: old, speed: 1, timeStep: 0.1, work: &work) }
        #expect(throws: LoadError.outsideDomain) { try service.step(law: p, accepted: old, speed: 11, timeStep: 0.1, work: &work) }
        var cancelled = try ThreeModelFixture.work(cancelled: true)
        #expect(throws: LoadError.cancelled) { try service.step(law: p, accepted: old, speed: 1, timeStep: 0.1, work: &cancelled) }
        var exhausted = try ThreeModelFixture.work(maximumWork: 99)
        #expect(throws: LoadError.workExhausted) { try service.step(law: p, accepted: old, speed: 1, timeStep: 0.1, work: &exhausted) }
        #expect(old.deflection == 0 && old.time == 0)
        #expect(throws: LoadError.invalidPassiveLaw) { try DahlFrictionLaw(stiffness: -1, limitingForce: 1, viscousCoefficient: 0, maximumSpeed: 1) }
    }
}

import Testing
import SwiftMechanics
import Darwin

@Suite struct BurgersCreepTests {
    let service: any BurgersCreepEvolving = ExactBurgersCreepEvolution()
    func law(_ maximumKelvin: Double = 1, _ maximumViscous: Double = 1) throws -> BurgersCreepLaw {
        try BurgersCreepLaw(maxwellModulus: 100, maxwellViscosity: 1000, kelvinModulus: 50, kelvinViscosity: 100,
            maximumStress: 100, maximumKelvinStrain: maximumKelvin, maximumViscousStrain: maximumViscous)
    }
    func virgin(_ p: BurgersCreepLaw) throws -> BurgersCreepState {
        try BurgersCreepState(law: p, time: 0, appliedStress: 0, kelvinStrain: 0, viscousStrain: 0)
    }
    @Test func independentCreepAndExplicitStressJumpWork() throws {
        let p = try law(), r = try service.step(law: p, accepted: virgin(p), appliedStress: 10, timeStep: 2)
        let kelvin = 0.2*(1-exp(-1))
        #expect(ConstitutiveFixture.near(r.state.kelvinStrain, kelvin))
        #expect(ConstitutiveFixture.near(r.state.viscousStrain, 0.02))
        #expect(ConstitutiveFixture.near(r.totalStrain, 0.1+0.02+kelvin))
        #expect(ConstitutiveFixture.near(r.endpointCreepRate, 0.01+0.1*exp(-1)))
        #expect(ConstitutiveFixture.near(r.stressJumpWork, 0.5))
        #expect(ConstitutiveFixture.near(r.heldStressWork, 10*(0.02+kelvin)))
        #expect(ConstitutiveFixture.near(r.dissipatedEnergy, 0.2+1-exp(-2)))
        #expect(ConstitutiveFixture.near(r.storedEnergy, 0.5+25*kelvin*kelvin))
        #expect(ConstitutiveFixture.near(r.energyResidual, 0))
    }
    @Test func heldIntervalCompositionAndColdValueReplay() throws {
        let p = try law(), initial = try virgin(p)
        let whole = try service.step(law: p, accepted: initial, appliedStress: 10, timeStep: 2)
        let first = try service.step(law: p, accepted: initial, appliedStress: 10, timeStep: 0.5)
        let restored = try BurgersCreepState(law: p, time: first.state.time, appliedStress: first.state.appliedStress,
            kelvinStrain: first.state.kelvinStrain, viscousStrain: first.state.viscousStrain)
        let second = try service.step(law: p, accepted: restored, appliedStress: 10, timeStep: 1.5)
        #expect(ConstitutiveFixture.near(whole.totalStrain, second.totalStrain))
        #expect(ConstitutiveFixture.near(whole.stressJumpWork+whole.heldStressWork,
            first.stressJumpWork+first.heldStressWork+second.stressJumpWork+second.heldStressWork))
        #expect(ConstitutiveFixture.near(whole.dissipatedEnergy, first.dissipatedEnergy+second.dissipatedEnergy))
        #expect(second.stressJumpWork == 0 && restored == first.state)
    }
    @Test func unloadingRecoveryAndStressReversalRemainPassive() throws {
        let p = try law(), loaded = try service.step(law: p, accepted: virgin(p), appliedStress: 10, timeStep: 2)
        let unloaded = try service.step(law: p, accepted: loaded.state, appliedStress: 0, timeStep: 2)
        #expect(ConstitutiveFixture.near(unloaded.elasticStrainJump, -0.1))
        #expect(ConstitutiveFixture.near(unloaded.stressJumpWork, -0.5))
        #expect(unloaded.heldStressWork == 0 && unloaded.dissipatedEnergy > 0)
        #expect(unloaded.state.viscousStrain == loaded.state.viscousStrain)
        #expect(ConstitutiveFixture.near(unloaded.state.kelvinStrain, loaded.state.kelvinStrain*exp(-1)))
        let reversed = try service.step(law: p, accepted: unloaded.state, appliedStress: -10, timeStep: 2)
        #expect(reversed.dissipatedEnergy > 0)
        #expect(ConstitutiveFixture.near(unloaded.energyResidual, 0))
        #expect(ConstitutiveFixture.near(reversed.energyResidual, 0))
    }
    @Test func tinyIntervalKeepsCreepAndLongHoldReachesKelvinEquilibrium() throws {
        let p = try law(), tiny = try service.step(law: p, accepted: virgin(p), appliedStress: 10, timeStep: 1e-12)
        #expect(ConstitutiveFixture.near(tiny.state.kelvinStrain, 1e-13, absolute: 1e-25))
        #expect(ConstitutiveFixture.near(tiny.state.viscousStrain, 1e-14, absolute: 1e-26))
        let longLaw = try law(1,100), held = try service.step(law: longLaw, accepted: virgin(longLaw), appliedStress: 10, timeStep: 100)
        #expect(ConstitutiveFixture.near(held.state.kelvinStrain, 0.2))
        #expect(ConstitutiveFixture.near(held.endpointCreepRate, 0.01))
    }
    @Test func parameterHistoryDomainTimeAndArithmeticFailuresPreserveInput() throws {
        let p = try law(), initial = try virgin(p)
        #expect(throws: MaterialError.invalidParameter(name: "burgersCreepLaw")) { try law(0,1) }
        #expect(throws: MaterialError.incompatibleHistory) { try service.step(law: law(2,1), accepted: initial, appliedStress: 1, timeStep: 1) }
        #expect(throws: MaterialError.self) { try service.step(law: p, accepted: initial, appliedStress: 101, timeStep: 1) }
        #expect(throws: MaterialError.self) { try service.step(law: p, accepted: initial, appliedStress: .nan, timeStep: 1) }
        let limitedK = try law(0.05,1), limitedV = try law(1,0.005)
        #expect(throws: MaterialError.self) { try service.step(law: limitedK, accepted: virgin(limitedK), appliedStress: 10, timeStep: 2) }
        #expect(throws: MaterialError.self) { try service.step(law: limitedV, accepted: virgin(limitedV), appliedStress: 10, timeStep: 2) }
        let late = try BurgersCreepState(law: p, time: 1e30, appliedStress: 0, kelvinStrain: 0, viscousStrain: 0)
        #expect(throws: MaterialError.invalidParameter(name: "unrepresentableTimeStep")) { try service.step(law: p, accepted: late, appliedStress: 1, timeStep: 1) }
        #expect(throws: MaterialError.self) { try service.step(law: p, accepted: initial, appliedStress: 10, timeStep: 1e308) }
        let enormous = try BurgersCreepLaw(maxwellModulus: 1, maxwellViscosity: 1e308, kelvinModulus: 1, kelvinViscosity: 1,
            maximumStress: 1e308, maximumKelvinStrain: 1e308, maximumViscousStrain: 1e308)
        #expect(throws: MaterialError.nonFiniteResult(operation: "BurgersCreep")) {
            try service.step(law: enormous, accepted: virgin(enormous), appliedStress: 1e308, timeStep: 1)
        }
        #expect(initial.kelvinStrain == 0 && initial.viscousStrain == 0 && initial.time == 0)
    }
    @Test func longUnloadingPreservesTheFiniteExponentialTail() throws {
        let p = try law(), initial = try BurgersCreepState(law: p, time: 0, appliedStress: 0,
            kelvinStrain: 0.3, viscousStrain: 0)
        let r = try service.step(law: p, accepted: initial, appliedStress: 0, timeStep: 100)
        #expect(ConstitutiveFixture.near(r.state.kelvinStrain, 0.3*exp(-50), absolute: 1e-35))
        #expect(ConstitutiveFixture.near(r.endpointCreepRate, -0.15*exp(-50), absolute: 1e-35))
        #expect(r.state.kelvinStrain > 0 && r.storedEnergy > 0)
    }
}

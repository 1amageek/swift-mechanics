import Testing
import SwiftMechanics
import Foundation

@Suite struct MaxwellRelaxationTests {
    let service: any MaxwellEvolving = ExactMaxwellEvolution()
    func law(_ modulus: Double = 120, _ viscosity: Double = 30) throws -> MaxwellLaw {
        try MaxwellLaw(modulus: modulus, viscosity: viscosity, maximumStress: 1000, maximumStrainRate: 10)
    }
    @Test func relaxationAndIndependentEnergy() throws {
        let p = try law(), old = try MaxwellState(law: p, time: 0, stress: 9)
        let result = try service.step(law: p, accepted: old, strainRate: 0, timeStep: 0.2)
        let expected = 9 * exp(-0.8), initialEnergy = 81.0 / 240
        #expect(AdditionalModelFixture.near(result.state.stress, expected))
        #expect(AdditionalModelFixture.near(result.dissipatedEnergy, initialEnergy * (1 - exp(-1.6))))
        #expect(AdditionalModelFixture.near(result.energyResidual, 0))
        #expect(result.inputWork == 0)
        #expect(old.stress == 9 && old.time == 0)
        let long = try service.step(law: p, accepted: old, strainRate: 0, timeStep: 10)
        #expect(AdditionalModelFixture.near(long.state.stress, 9 * exp(-40), absolute: 1e-30))
    }
    @Test func heldRateCompositionAndWork() throws {
        let p = try law(), old = try MaxwellState(law: p, time: 1, stress: -7)
        let whole = try service.step(law: p, accepted: old, strainRate: 2, timeStep: 0.3)
        let a = try service.step(law: p, accepted: old, strainRate: 2, timeStep: 0.1)
        let b = try service.step(law: p, accepted: a.state, strainRate: 2, timeStep: 0.2)
        #expect(AdditionalModelFixture.near(whole.state.stress, 60 + (-7 - 60) * exp(-1.2)))
        #expect(AdditionalModelFixture.near(whole.state.stress, b.state.stress))
        #expect(AdditionalModelFixture.near(whole.inputWork, a.inputWork + b.inputWork))
        #expect(AdditionalModelFixture.near(whole.dissipatedEnergy, a.dissipatedEnergy + b.dissipatedEnergy))
        #expect(AdditionalModelFixture.near(whole.energyResidual, 0))
        #expect(whole.dissipatedEnergy >= 0)
    }
    @Test func tinyIntervalAndLawIdentity() throws {
        let p = try law(), old = try MaxwellState(law: p, time: 0, stress: 0)
        let tiny = try service.step(law: p, accepted: old, strainRate: 1, timeStep: 1e-12)
        #expect(AdditionalModelFixture.near(tiny.state.stress, 120e-12, absolute: 1e-22, relative: 1e-10))
        #expect(tiny.dissipatedEnergy > 0)
        #expect(throws: MaterialError.incompatibleHistory) {
            try service.step(law: self.law(121), accepted: old, strainRate: 1, timeStep: 0.1)
        }
        #expect(throws: MaterialError.invalidParameter(name: "MaxwellStep")) {
            try service.step(law: p, accepted: old, strainRate: 0, timeStep: 0)
        }
        #expect(throws: MaterialError.invalidParameter(name: "MaxwellLaw")) { try law(-1) }
        #expect(throws: MaterialError.outsideDomain(measure: "strainRate", value: 11, limit: 10)) {
            try service.step(law: p, accepted: old, strainRate: 11, timeStep: 0.1)
        }
    }
}

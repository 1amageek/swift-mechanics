import Testing
import SwiftMechanics
import Darwin

@Suite struct StandardLinearSolidTests {
    let service: any StandardLinearSolidEvolving = ExactStandardLinearSolidEvolution()
    func law(_ equilibrium: Double = 50) throws -> StandardLinearSolidLaw {
        try StandardLinearSolidLaw(equilibriumModulus: equilibrium,
            branchLaw: MaxwellLaw(modulus: 100, viscosity: 200, maximumStress: 100, maximumStrainRate: 0.1), maximumStrain: 0.2)
    }
    @Test func relaxationRetainsEquilibriumStress() throws {
        let p = try law(), initial = try StandardLinearSolidState(law: p, time: 0, strain: 0.1, branchStress: 5)
        let r = try service.step(law: p, accepted: initial, strainRate: 0, timeStep: 2)
        #expect(ConstitutiveFixture.near(r.endpointStress, 5+5*exp(-1)))
        #expect(ConstitutiveFixture.near(r.meanStress, 5+5*(1-exp(-1))))
        #expect(ConstitutiveFixture.near(r.storedEnergy, 0.25+0.125*exp(-2)))
        #expect(ConstitutiveFixture.near(r.dissipatedEnergy, 0.125*(1-exp(-2))))
        #expect(r.inputWork == 0 && r.state.strain == initial.strain && r.state.time == 2)
        #expect(ConstitutiveFixture.near(r.energyResidual, 0))
        #expect(initial.branchState.stress == 5 && initial.time == 0)
    }
    @Test func rampOriginalWorkAndIndependentViscousIntegral() throws {
        let p = try law(), initial = try StandardLinearSolidState(law: p, time: 0, strain: 0, branchStress: 0)
        let r = try service.step(law: p, accepted: initial, strainRate: 0.01, timeStep: 2)
        #expect(ConstitutiveFixture.near(r.endpointStress, 1+2*(1-exp(-1))))
        #expect(ConstitutiveFixture.near(r.meanStress, 0.5+2*exp(-1)))
        #expect(ConstitutiveFixture.near(r.inputWork, (0.5+2*exp(-1))*0.02))
        var integral = 0.0
        let n = 2048, dt = 2/Double(n)
        for i in 0...n {
            let branch = 2*(1-exp(-0.5*Double(i)*dt))
            let weight = i == 0 || i == n ? 1.0 : (i % 2 == 0 ? 2.0 : 4.0)
            integral += weight*branch*branch/200
        }
        integral *= dt/3
        #expect(ConstitutiveFixture.near(r.dissipatedEnergy, integral, absolute: 1e-12))
        #expect(ConstitutiveFixture.near(r.inputWork, r.storageChange+r.dissipatedEnergy))
    }
    @Test func intervalCompositionAndReversalPreservePassiveHistory() throws {
        let p = try law(), initial = try StandardLinearSolidState(law: p, time: 0, strain: 0, branchStress: 0)
        let whole = try service.step(law: p, accepted: initial, strainRate: 0.03, timeStep: 2)
        let first = try service.step(law: p, accepted: initial, strainRate: 0.03, timeStep: 0.75)
        let second = try service.step(law: p, accepted: first.state, strainRate: 0.03, timeStep: 1.25)
        #expect(ConstitutiveFixture.near(whole.endpointStress, second.endpointStress))
        #expect(ConstitutiveFixture.near(whole.state.strain, second.state.strain))
        #expect(ConstitutiveFixture.near(whole.inputWork, first.inputWork+second.inputWork))
        #expect(ConstitutiveFixture.near(whole.dissipatedEnergy, first.dissipatedEnergy+second.dissipatedEnergy))
        let reversed = try service.step(law: p, accepted: whole.state, strainRate: -0.03, timeStep: 2)
        #expect(ConstitutiveFixture.near(reversed.state.strain, 0))
        #expect(reversed.dissipatedEnergy > 0)
        #expect(ConstitutiveFixture.near(reversed.energyResidual, 0))
    }
    @Test func lawEnvelopeTimeAndArithmeticRefusalsPreserveAcceptedState() throws {
        let p = try law(), initial = try StandardLinearSolidState(law: p, time: 0, strain: 0, branchStress: 0)
        #expect(throws: MaterialError.invalidParameter(name: "standardLinearSolidLaw")) { try law(-1) }
        #expect(throws: MaterialError.incompatibleHistory) { try service.step(law: law(51), accepted: initial, strainRate: 0, timeStep: 1) }
        #expect(throws: MaterialError.self) { try service.step(law: p, accepted: initial, strainRate: 0.1, timeStep: 3) }
        #expect(throws: MaterialError.self) { try service.step(law: p, accepted: initial, strainRate: 0.2, timeStep: 0.5) }
        #expect(throws: MaterialError.self) { try service.step(law: p, accepted: initial, strainRate: .nan, timeStep: 1) }
        let late = try StandardLinearSolidState(law: p, time: 1e30, strain: 0, branchStress: 0)
        #expect(throws: MaterialError.invalidParameter(name: "unrepresentableTimeStep")) { try service.step(law: p, accepted: late, strainRate: 0, timeStep: 1) }
        let huge = try law(1e308), loaded = try StandardLinearSolidState(law: huge, time: 0, strain: 0.1, branchStress: 0)
        #expect(throws: MaterialError.nonFiniteResult(operation: "StandardLinearSolid")) {
            try service.step(law: huge, accepted: loaded, strainRate: 1e308, timeStep: 2)
        }
        #expect(initial.strain == 0 && initial.branchState.stress == 0 && initial.time == 0)
    }
    @Test func injectedPublicSupplierAssociationIsChecked() throws {
        let bad: any StandardLinearSolidEvolving = ExactStandardLinearSolidEvolution(branchEvolution: WrongTimeMaxwell())
        let p = try law(), initial = try StandardLinearSolidState(law: p, time: 0, strain: 0, branchStress: 0)
        #expect(throws: MaterialError.incompatibleHistory) { try bad.step(law: p, accepted: initial, strainRate: 0.01, timeStep: 1) }
    }
}

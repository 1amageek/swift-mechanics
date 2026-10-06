import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1))) struct TurbulentHydraulicOrificeTests {

    @Test func originalBernoulliFixture() throws {
        let law: any HydraulicResistanceEvaluating = try TurbulentHydraulicOrifice(dischargeCoefficient: 0.6, area: 0.002, density: 1000)
        var work = try HydraulicFixture.work()
        let r = try law.evaluate(pressureDifference: 2000, work: &work)
        #expect(HydraulicFixture.near(r.volumeFlow, 0.0024))
        #expect(HydraulicFixture.near(r.dissipatedPower, 4.8))
        HydraulicFixture.balanced(r)
    }
    @Test func forwardReverseAndZero() throws {
        let law = try TurbulentHydraulicOrifice(dischargeCoefficient: 1, area: 2, density: 2)
        var work = try HydraulicFixture.work()
        for p in [-4.0, 0, 4] {
            let r = try law.evaluate(pressureDifference: p, work: &work)
            #expect(r.volumeFlow == p)
            HydraulicFixture.balanced(r)
        }
    }
    @Test func pressureAndAreaScaling() throws {
        let a = try TurbulentHydraulicOrifice(dischargeCoefficient: 1, area: 1, density: 2)
        let b = try TurbulentHydraulicOrifice(dischargeCoefficient: 1, area: 2, density: 2)
        var work = try HydraulicFixture.work()
        #expect(try a.evaluate(pressureDifference: 16, work: &work).volumeFlow == 4)
        #expect(try b.evaluate(pressureDifference: 4, work: &work).volumeFlow == 4)
    }
    @Test func originalDerivativeRefinement() throws {
        let law = try TurbulentHydraulicOrifice(dischargeCoefficient: 1, area: 1, density: 2)
        var work = try HydraulicFixture.work()
        for h in [1e-6, 5e-7] {
            let plus = try law.evaluate(pressureDifference: 4+h, work: &work)
            let minus = try law.evaluate(pressureDifference: 4-h, work: &work)
            #expect(HydraulicFixture.near((plus.volumeFlow-minus.volumeFlow)/(2*h), 0.25, absolute: 1e-8, relative: 1e-6))
        }
    }
    @Test func malformedParametersAndQuery() throws {
        #expect(throws: ActuationError.invalidLaw) { try TurbulentHydraulicOrifice(dischargeCoefficient: 0, area: 1, density: 1) }
        #expect(throws: ActuationError.invalidLaw) { try TurbulentHydraulicOrifice(dischargeCoefficient: 1, area: -1, density: 1) }
        #expect(throws: ActuationError.invalidLaw) { try TurbulentHydraulicOrifice(dischargeCoefficient: 1, area: 1, density: .infinity) }
        var work = try HydraulicFixture.work()
        let law = try TurbulentHydraulicOrifice(dischargeCoefficient: 1, area: 1, density: 2)
        #expect(throws: ActuationError.invalidInput) { try law.evaluate(pressureDifference: .infinity, work: &work) }
    }
    @Test func overflowRefusesWithoutFlowClipping() throws {
        let law = try TurbulentHydraulicOrifice(dischargeCoefficient: 1e308, area: 1e308, density: 1)
        var work = try HydraulicFixture.work()
        #expect(throws: ActuationError.nonfiniteResult) { try law.evaluate(pressureDifference: 1, work: &work) }
    }
}

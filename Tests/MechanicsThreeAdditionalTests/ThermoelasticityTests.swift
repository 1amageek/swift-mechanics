import Testing
import SwiftMechanics

@Suite struct ThermoelasticityTests {
    let service: any ThermoelasticEvaluating = ThermoelasticEvaluator()
    func law(_ coefficient: Double = 1e-5) throws -> ThermoelasticLaw {
        try ThermoelasticLaw(elasticity: IsotropicElasticity(bulkModulus: 100000, shearModulus: 40000),
            strainDomain: StrainDomain(maximumStrainNorm: 0.1, minimumVolumeRatio: 0.5),
            expansionCoefficient: coefficient, referenceTemperature: 300, minimumTemperature: 250, maximumTemperature: 600)
    }
    @Test func freeExpansionAndConstrainedStress() throws {
        let p = try law(), expansion = try SymmetricTensor.isotropic(0.001)
        let free = try service.evaluate(law: p, totalStrain: expansion, temperature: 400, strainRate: .zero, temperatureRate: 0)
        #expect(free.stress == .zero && free.freeEnergyDensity == 0)
        let fixed = try service.evaluate(law: p, totalStrain: .zero, temperature: 400, strainRate: .zero, temperatureRate: 1)
        #expect(try ThreeModelFixture.tensorNear(fixed.stress, SymmetricTensor.isotropic(-300)))
        #expect(ThreeModelFixture.near(fixed.freeEnergyDensity, 0.45))
        #expect(ThreeModelFixture.near(fixed.thermalPowerDensity, 0.009))
        #expect(try ThreeModelFixture.tensorNear(fixed.stressTemperatureDerivative, SymmetricTensor.isotropic(-3)))
    }
    @Test func originalEnergyRateAndCoupledTangent() throws {
        let p = try law(), e = try SymmetricTensor(xx: 0.003, yy: -0.002, zz: 0.001, xy: 0.004)
        let rate = try SymmetricTensor(xx: 0.002, yy: 0.001, zz: -0.001, xy: 0.003, yz: -0.002)
        let t = 350.0, tDot = 1.5, h = 1e-5
        let result = try service.evaluate(law: p, totalStrain: e, temperature: t, strainRate: rate, temperatureRate: tDot)
        let plus = try service.evaluate(law: p, totalStrain: e.adding(rate.scaled(by: h)), temperature: t+h*tDot, strainRate: .zero, temperatureRate: 0)
        let minus = try service.evaluate(law: p, totalStrain: e.subtracting(rate.scaled(by: h)), temperature: t-h*tDot, strainRate: .zero, temperatureRate: 0)
        let tangent = try service.tangent(law: p, strainDirection: rate, temperatureDirection: tDot)
        let numerical = try plus.stress.subtracting(minus.stress).scaled(by: 1/(2*h))
        #expect(ThreeModelFixture.tensorNear(tangent, numerical))
        #expect(ThreeModelFixture.near(result.freeEnergyRate, (plus.freeEnergyDensity-minus.freeEnergyDensity)/(2*h)))
        #expect(ThreeModelFixture.near(result.freeEnergyRate, result.mechanicalPowerDensity+result.thermalPowerDensity))
    }
    @Test func zeroAndNegativeExpansionAreExplicitLaws() throws {
        let p = try law(0), strain = try SymmetricTensor(xx: 0.005, yy: -0.002, zz: 0, xy: 0.001)
        let cold = try service.evaluate(law: p, totalStrain: strain, temperature: 250, strainRate: .zero, temperatureRate: 100)
        let hot = try service.evaluate(law: p, totalStrain: strain, temperature: 600, strainRate: .zero, temperatureRate: -100)
        #expect(cold.stress == hot.stress && cold.freeEnergyDensity == hot.freeEnergyDensity)
        #expect(cold.stressTemperatureDerivative == .zero && cold.thermalPowerDensity == 0)
        let negative = try service.evaluate(law: law(-1e-5), totalStrain: .zero, temperature: 400, strainRate: .zero, temperatureRate: 0)
        #expect(negative.stress.xx > 0)
    }
    @Test func domainAndNonfiniteFailures() throws {
        #expect(throws: MaterialError.invalidParameter(name: "thermalSample")) {
            try service.evaluate(law: law(), totalStrain: .zero, temperature: .nan, strainRate: .zero, temperatureRate: 0)
        }
        #expect(throws: MaterialError.outsideDomain(measure: "temperature", value: 700, limit: 600)) {
            try service.evaluate(law: law(), totalStrain: .zero, temperature: 700, strainRate: .zero, temperatureRate: 0)
        }
        #expect(throws: MaterialError.outsideDomain(measure: "temperature", value: 240, limit: 250)) {
            try service.evaluate(law: law(), totalStrain: .zero, temperature: 240, strainRate: .zero, temperatureRate: 0)
        }
        #expect(throws: MaterialError.self) {
            try service.evaluate(law: law(), totalStrain: SymmetricTensor.isotropic(0.2), temperature: 300, strainRate: .zero, temperatureRate: 0)
        }
        #expect(throws: MaterialError.nonFiniteResult(operation: "Thermoelasticity")) {
            try service.evaluate(law: law(1e308), totalStrain: .zero, temperature: 400, strainRate: .zero, temperatureRate: 0)
        }
    }
}

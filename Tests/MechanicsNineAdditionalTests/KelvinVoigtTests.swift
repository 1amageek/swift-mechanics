import Testing
import SwiftMechanics

@Suite struct KelvinVoigtTests {
    let service: any KelvinVoigtEvaluating = KelvinVoigtEvaluator()
    func law(_ bulk: Double = 10, _ shear: Double = 20) throws -> KelvinVoigtLaw {
        try KelvinVoigtLaw(elasticity: IsotropicElasticity(bulkModulus: 1000, shearModulus: 400),
            strainDomain: NineServiceFixture.domain(), bulkViscosity: bulk, shearViscosity: shear, maximumRateNorm: 1)
    }
    @Test func independentTensorStressAndPower() throws {
        let strain = try SymmetricTensor(xx: 0.01, yy: 0.01, zz: 0.01, xy: 0.02)
        let rate = try SymmetricTensor(xx: 0.1, yy: 0.1, zz: 0.1, xy: 0.02)
        let r = try service.evaluate(law: law(), strain: strain, strainRate: rate)
        #expect(NineServiceFixture.near(r.stress.xx, 33))
        #expect(NineServiceFixture.near(r.stress.xy, 16.8))
        #expect(NineServiceFixture.near(r.energyDensity, 0.77))
        #expect(NineServiceFixture.near(r.dissipatedPowerDensity, 0.932))
        #expect(NineServiceFixture.near(r.energyRate, 9.64))
        #expect(NineServiceFixture.near(r.stressPowerDensity, 10.572))
        #expect(NineServiceFixture.near(r.powerResidual, 0))
    }
    @Test func coupledTangentAndOriginalEnergyGradient() throws {
        let p = try law(), e = try SymmetricTensor(xx: 0.01, yy: -0.02, zz: 0.03, xy: 0.02)
        let v = try SymmetricTensor(xx: 0.02, yy: 0.01, zz: -0.03, xz: 0.02)
        let de = try SymmetricTensor(xx: 0.002, yy: -0.001, zz: 0.003, yz: 0.004)
        let dv = try SymmetricTensor(xx: 0.01, yy: 0.02, zz: -0.01, xy: -0.02)
        let h = 1e-5
        let plus = try service.evaluate(law: p, strain: e.adding(de.scaled(by: h)), strainRate: v.adding(dv.scaled(by: h)))
        let minus = try service.evaluate(law: p, strain: e.subtracting(de.scaled(by: h)), strainRate: v.subtracting(dv.scaled(by: h)))
        let tangent = try service.tangent(law: p, strainDirection: de, rateDirection: dv)
        #expect(try NineServiceFixture.tensorNear(tangent, plus.stress.subtracting(minus.stress).scaled(by: 1/(2*h))))
        let r = try service.evaluate(law: p, strain: e, strainRate: v)
        #expect(try NineServiceFixture.near((plus.energyDensity-minus.energyDensity)/(2*h), r.elasticStress.contracted(with: de)))
        #expect(NineServiceFixture.near(r.stressPowerDensity, r.energyRate+r.dissipatedPowerDensity))
    }
    @Test func zeroViscosityAndRateReversal() throws {
        let e = try SymmetricTensor(xx: 0.01, yy: 0, zz: 0)
        let v = try SymmetricTensor(xx: 0.03, yy: 0.02, zz: -0.01, xy: 0.02)
        let elastic = try service.evaluate(law: law(0,0), strain: e, strainRate: v)
        #expect(elastic.viscousStress == .zero && elastic.dissipatedPowerDensity == 0)
        let positive = try service.evaluate(law: law(), strain: e, strainRate: v)
        let negative = try service.evaluate(law: law(), strain: e, strainRate: v.scaled(by: -1))
        #expect(try NineServiceFixture.tensorNear(positive.viscousStress, negative.viscousStress.scaled(by: -1)))
        #expect(NineServiceFixture.near(positive.dissipatedPowerDensity, negative.dissipatedPowerDensity))
    }
    @Test func invalidLawDomainAndArithmeticFailure() throws {
        #expect(throws: MaterialError.invalidParameter(name: "kelvinVoigtLaw")) { try law(-1,20) }
        #expect(throws: MaterialError.self) {
            try service.evaluate(law: law(), strain: SymmetricTensor.isotropic(1), strainRate: .zero)
        }
        #expect(throws: MaterialError.self) {
            try service.evaluate(law: law(), strain: .zero, strainRate: SymmetricTensor.isotropic(1))
        }
        #expect(throws: MaterialError.self) {
            try service.tangent(law: law(), strainDirection: .zero, rateDirection: SymmetricTensor.isotropic(1e308))
        }
    }
}

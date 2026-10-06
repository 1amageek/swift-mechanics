import Testing
import SwiftMechanics

@Suite struct OrthotropicElasticityTests {
    let service: any OrthotropicElasticEvaluating = OrthotropicElasticEvaluator()
    func law() throws -> OrthotropicElasticLaw {
        try OrthotropicElasticLaw(c11: 120, c22: 180, c33: 240, c12: 20, c13: 30, c23: 40, g12: 50, g23: 60, g13: 70)
    }
    @Test func independentAxesAndTensorShear() throws {
        let e = try SymmetricTensor(xx: 0.1, yy: 0.02, zz: -0.03, xy: 0.04, yz: 0.01, xz: -0.02)
        let r = try service.evaluate(law: law(), strain: e, domain: NineServiceFixture.domain())
        #expect(try NineServiceFixture.tensorNear(r.stress, SymmetricTensor(xx: 11.5, yy: 4.4, zz: -3.4, xy: 4, yz: 1.2, xz: -2.8)))
        #expect(NineServiceFixture.near(r.energyDensity, 0.898))
        #expect(try NineServiceFixture.near(r.energyDensity, 0.5*e.contracted(with: r.stress)))
    }
    @Test func originalEnergyGradientAndStressTangent() throws {
        let p = try law(), e = try SymmetricTensor(xx: 0.1, yy: -0.04, zz: 0.03, xy: 0.02)
        let direction = try SymmetricTensor(xx: 0.02, yy: 0.01, zz: -0.03, yz: 0.01, xz: -0.01)
        let h = 1e-5, domain = try NineServiceFixture.domain()
        let plus = try service.evaluate(law: p, strain: e.adding(direction.scaled(by: h)), domain: domain)
        let minus = try service.evaluate(law: p, strain: e.subtracting(direction.scaled(by: h)), domain: domain)
        let r = try service.evaluate(law: p, strain: e, domain: domain)
        #expect(try NineServiceFixture.tensorNear(service.tangent(law: p, direction: direction), plus.stress.subtracting(minus.stress).scaled(by: 1/(2*h))))
        #expect(try NineServiceFixture.near((plus.energyDensity-minus.energyDensity)/(2*h), r.stress.contracted(with: direction)))
    }
    @Test func isotropicReductionAndRecovery() throws {
        let isotropic = try IsotropicElasticity(bulkModulus: 1000, shearModulus: 400)
        let lambda = isotropic.lameLambda
        let p = try OrthotropicElasticLaw(c11: lambda+800, c22: lambda+800, c33: lambda+800,
            c12: lambda, c13: lambda, c23: lambda, g12: 400, g23: 400, g13: 400)
        let e = try SymmetricTensor(xx: 0.01, yy: -0.02, zz: 0.03, xy: 0.01, yz: 0.02, xz: -0.01)
        let domain = try NineServiceFixture.domain()
        let original = try isotropic.evaluate(strain: e, domain: domain)
        let result = try service.evaluate(law: p, strain: e, domain: domain)
        #expect(NineServiceFixture.tensorNear(original.stress, result.stress))
        #expect(NineServiceFixture.near(original.energyDensity, result.energyDensity))
        let reversed = try service.evaluate(law: p, strain: e.scaled(by: -1), domain: domain)
        #expect(result.energyDensity == reversed.energyDensity)
        let zero = try service.evaluate(law: p, strain: .zero, domain: domain)
        #expect(zero.stress == .zero && zero.energyDensity == 0)
    }
    @Test func rejectsIndefiniteSemidefiniteDomainAndOverflow() throws {
        #expect(throws: MaterialError.invalidParameter(name: "orthotropicPositiveDefiniteness")) {
            try OrthotropicElasticLaw(c11: 1, c22: 1, c33: 1, c12: 2, c13: 0, c23: 0, g12: 1, g23: 1, g13: 1)
        }
        #expect(throws: MaterialError.invalidParameter(name: "orthotropicPositiveDefiniteness")) {
            try OrthotropicElasticLaw(c11: 1, c22: 1, c33: 1, c12: 1, c13: 0, c23: 0, g12: 1, g23: 1, g13: 1)
        }
        #expect(throws: MaterialError.invalidParameter(name: "orthotropicPositiveDefiniteness")) {
            try OrthotropicElasticLaw(c11: 1, c22: 1, c33: 1, c12: 0, c13: 0.9, c23: 0.9, g12: 1, g23: 1, g13: 1)
        }
        #expect(throws: MaterialError.self) {
            try service.evaluate(law: law(), strain: SymmetricTensor.isotropic(1), domain: NineServiceFixture.domain())
        }
        #expect(throws: MaterialError.nonFiniteResult(operation: "OrthotropicElasticity")) {
            try service.tangent(law: law(), direction: SymmetricTensor(xx: 1e308, yy: 0, zz: 0))
        }
    }
}

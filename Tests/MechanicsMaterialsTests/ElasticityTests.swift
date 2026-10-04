import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ElasticityTests {
    @Test func linearUniaxialAndShearRecovery() throws {
        let material: any LinearElasticResponding = try MaterialsFixtures.elasticity()
        let poisson = (3000.0 - 800) / (2 * (3000 + 400))
        let young = 9.0 * 1000 * 400 / (3000 + 400)
        let uniaxial = try SymmetricTensor(xx: 0.01, yy: -poisson * 0.01, zz: -poisson * 0.01)
        let axial = try material.evaluate(strain: uniaxial, domain: MaterialsFixtures.domain())
        #expect(MaterialsFixtures.close(axial.stress.xx, young * 0.01))
        #expect(abs(axial.stress.yy) <= 1e-9)
        #expect(abs(axial.stress.zz) <= 1e-9)
        #expect(MaterialsFixtures.close(axial.energyDensity, 0.5 * young * 0.01 * 0.01))
        let shear = try SymmetricTensor(xx: 0, yy: 0, zz: 0, xy: 0.02)
        let sheared = try material.evaluate(strain: shear, domain: MaterialsFixtures.domain())
        #expect(MaterialsFixtures.close(sheared.stress.xy, 16))
        #expect(MaterialsFixtures.close(sheared.energyDensity, 0.32))
        let recovered = try material.evaluate(strain: .zero, domain: MaterialsFixtures.domain())
        #expect(recovered.stress == .zero)
        #expect(recovered.energyDensity == 0)
        #expect(try material.tangent(direction: shear) == sheared.stress)
    }

    @Test func nonlinearStretchHasAnalyticStressAndEnergy() throws {
        let material: any HyperelasticResponding = try PolynomialHyperelasticity(
            elasticity: MaterialsFixtures.elasticity(), nonlinearModulus: 800, domain: MaterialsFixtures.domain())
        let f = try Matrix3(1.1, 0, 0, 0, 1, 0, 0, 0, 1)
        let response = try material.evaluate(deformationGradient: f)
        let e = 0.105, lambda = 1000.0 - 800 / 3
        let sxx = (lambda + 800) * e + 800 * e * e * e
        #expect(MaterialsFixtures.close(response.greenStrain.xx, e, absolute: 1e-12))
        #expect(MaterialsFixtures.close(response.secondPiolaStress.xx, sxx))
        #expect(MaterialsFixtures.close(response.secondPiolaStress.yy, lambda * e))
        #expect(MaterialsFixtures.close(response.firstPiolaStress.m00, 1.1 * sxx))
        #expect(MaterialsFixtures.close(response.cauchyStress.m00, 1.1 * sxx))
        #expect(MaterialsFixtures.close(response.energyDensity, 0.5 * (lambda + 800) * e * e + 200 * e * e * e * e))
        let recovered = try material.evaluate(deformationGradient: .identity)
        #expect(recovered.secondPiolaStress == .zero)
        #expect(recovered.energyDensity == 0)
    }

    @Test func finiteObjectivityAndAnalyticDirectionalTangent() throws {
        let material: any HyperelasticResponding = try PolynomialHyperelasticity(
            elasticity: MaterialsFixtures.elasticity(), nonlinearModulus: 800, domain: MaterialsFixtures.domain())
        let f = try Matrix3(1.08, 0.03, 0.01, -0.02, 0.98, 0.04, 0.02, -0.01, 1.03)
        let h = try Matrix3(0.13, 0.21, -0.1, 0.04, -0.07, 0.09, 0.03, -0.11, 0.08)
        let base = try material.evaluate(deformationGradient: f)
        let q = try UnitQuaternion(axis: Vector3(1, 2, 3), angle: 1.3).matrix()
        let rotated = try material.evaluate(deformationGradient: q.multiplied(by: f))
        #expect(try MaterialsFixtures.tensorClose(rotated.greenStrain, base.greenStrain, absolute: 1e-12))
        #expect(try MaterialsFixtures.tensorClose(rotated.secondPiolaStress, base.secondPiolaStress))
        #expect(try MaterialsFixtures.matrixClose(rotated.firstPiolaStress, q.multiplied(by: base.firstPiolaStress), absolute: 1e-9, relative: 1e-10))
        #expect(try MaterialsFixtures.matrixClose(rotated.cauchyStress, q.multiplied(by: base.cauchyStress).multiplied(by: q.transposed()), absolute: 1e-9, relative: 1e-10))
        #expect(MaterialsFixtures.close(rotated.energyDensity, base.energyDensity))
        let pureRotation = try material.evaluate(deformationGradient: q)
        #expect(try pureRotation.greenStrain.norm() < 1e-12)
        #expect(try pureRotation.secondPiolaStress.norm() < 1e-9)

        let step = 1e-6
        let plus = try material.evaluate(deformationGradient: f.adding(h.scaled(by: step)))
        let minus = try material.evaluate(deformationGradient: f.subtracting(h.scaled(by: step)))
        let derivative = try material.tangent(deformationGradient: f, direction: h)
        #expect(try MaterialsFixtures.matrixClose(derivative.firstPiolaDirection, plus.firstPiolaStress.subtracting(minus.firstPiolaStress).scaled(by: 0.5 / step)))
        #expect(try MaterialsFixtures.matrixClose(derivative.cauchyDirection, plus.cauchyStress.subtracting(minus.cauchyStress).scaled(by: 0.5 / step)))
        #expect(try MaterialsFixtures.tensorClose(derivative.secondPiolaDirection, plus.secondPiolaStress.subtracting(minus.secondPiolaStress).scaled(by: 0.5 / step), absolute: 1e-3, relative: 1e-6))
        #expect(MaterialsFixtures.close((plus.energyDensity - minus.energyDensity) / (2 * step), try MaterialsFixtures.contraction(base.firstPiolaStress, h), absolute: 1e-6, relative: 1e-6))
        let rotatedDerivative = try material.tangent(deformationGradient: q.multiplied(by: f), direction: q.multiplied(by: h))
        #expect(try MaterialsFixtures.matrixClose(rotatedDerivative.firstPiolaDirection, q.multiplied(by: derivative.firstPiolaDirection)))
    }

    @Test func simpleShearKinematicsAndInvalidDomains() throws {
        let domain = try MaterialsFixtures.domain()
        let shear = try Matrix3(1, 0.2, 0, 0, 1, 0, 0, 0, 1)
        let kinematics = try FiniteStrainKinematics(deformationGradient: shear, domain: domain)
        #expect(MaterialsFixtures.close(kinematics.greenStrain.xy, 0.1, absolute: 1e-12))
        #expect(MaterialsFixtures.close(kinematics.greenStrain.yy, 0.02, absolute: 1e-12))
        #expect(kinematics.volumeRatio == 1)
        #expect(throws: MaterialError.invalidParameter(name: "bulkModulus")) { try IsotropicElasticity(bulkModulus: -1, shearModulus: 1) }
        #expect(throws: MaterialError.invalidParameter(name: "shearModulus")) { try IsotropicElasticity(bulkModulus: 1, shearModulus: .nan) }
        #expect(throws: MaterialError.invalidParameter(name: "nonlinearModulus")) { try PolynomialHyperelasticity(elasticity: MaterialsFixtures.elasticity(), nonlinearModulus: -1, domain: domain) }
        #expect(throws: MaterialError.invalidParameter(name: "minimumVolumeRatio")) { try StrainDomain(maximumStrainNorm: 1, minimumVolumeRatio: 0) }
        #expect(throws: MaterialError.outsideDomain(measure: "volumeRatio", value: -1, limit: 0.2)) {
            try FiniteStrainKinematics(deformationGradient: Matrix3(-1, 0, 0, 0, 1, 0, 0, 0, 1), domain: domain)
        }
        let tinyDomain = try StrainDomain(maximumStrainNorm: 0.01, minimumVolumeRatio: 0.2)
        #expect(throws: MaterialError.self) { try FiniteStrainKinematics(deformationGradient: shear, domain: tinyDomain) }
        let extreme = try SymmetricTensor(xx: 1e200, yy: 0, zz: 0)
        #expect(throws: MaterialError.nonFiniteResult(operation: "tensorContraction")) {
            try MaterialsFixtures.elasticity().evaluate(strain: extreme, domain: StrainDomain(maximumStrainNorm: 1e201, minimumVolumeRatio: 0.2))
        }
        #expect(try SymmetricTensor(xx: .leastNonzeroMagnitude, yy: 0, zz: 0).norm() == .leastNonzeroMagnitude)
        #expect(throws: MaterialError.core(.nonFiniteResult)) {
            try FiniteStrainKinematics(deformationGradient: Matrix3.identity.scaled(by: 1e200), domain: domain)
        }
    }
}

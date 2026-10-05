import Testing
import SwiftMechanics
import Darwin

@Suite struct NeoHookeanTests {
    let service: any NeoHookeanEvaluating = NeoHookeanEvaluator()
    func law() throws -> NeoHookeanLaw {
        try NeoHookeanLaw(shearModulus: 20, lameLambda: 30, domain: StrainDomain(maximumStrainNorm: 2, minimumVolumeRatio: 0.2))
    }
    @Test func independentFiniteStretchAndElasticRecovery() throws {
        let p = try law(), f = try ConstitutiveFixture.diagonal(1.2,0.9,1.1)
        let r = try service.evaluate(law: p, deformationGradient: f)
        let j = 1.2*0.9*1.1, logarithm = log(j), coefficient = 30*logarithm-20
        let expectedP = try ConstitutiveFixture.diagonal(24+coefficient/1.2,18+coefficient/0.9,22+coefficient/1.1)
        let expectedS = try ConstitutiveFixture.diagonal(20+coefficient/(1.2*1.2),20+coefficient/(0.9*0.9),20+coefficient/(1.1*1.1))
        #expect(try ConstitutiveFixture.matrixNear(r.firstPiolaStress, expectedP))
        #expect(try ConstitutiveFixture.matrixNear(r.secondPiolaStress, expectedS))
        #expect(ConstitutiveFixture.near(r.volumeRatio, j))
        #expect(ConstitutiveFixture.near(r.energyDensity, 10*(1.2*1.2+0.9*0.9+1.1*1.1-3)-20*logarithm+15*logarithm*logarithm))
        let zero = try service.evaluate(law: p, deformationGradient: .identity)
        #expect(zero.firstPiolaStress == .zero && zero.energyDensity == 0)
    }
    @Test func independentSimpleShearAndTinyEnergy() throws {
        let p = try law(), f = try Matrix3(1,0.2,0,0,1,0,0,0,1)
        let r = try service.evaluate(law: p, deformationGradient: f)
        #expect(ConstitutiveFixture.near(r.energyDensity, 0.4))
        #expect(try ConstitutiveFixture.matrixNear(r.firstPiolaStress, Matrix3(0,4,0,4,0,0,0,0,0)))
        #expect(try ConstitutiveFixture.matrixNear(r.cauchyStress, Matrix3(0.8,4,0,4,0,0,0,0,0)))
        let tiny = try service.evaluate(law: p, deformationGradient: Matrix3(1,1e-20,0,0,1,0,0,0,1))
        #expect(ConstitutiveFixture.near(tiny.energyDensity, 1e-39, absolute: 1e-51))
        let stretch = 1+1e-9, u = stretch-1
        let small = try service.evaluate(law: p, deformationGradient: ConstitutiveFixture.diagonal(stretch,stretch,stretch))
        #expect(ConstitutiveFixture.near(small.energyDensity, 195*u*u, absolute: 1e-26, relative: 1e-6))
    }
    @Test func allStressTangentsAndOriginalPotentialGradient() throws {
        let p = try law(), f = try Matrix3(1.1,0.1,0.03,0.02,0.95,0.04,0,0.03,1.05)
        let direction = try Matrix3(0.03,-0.02,0.01,0.01,0.02,-0.03,-0.02,0.01,0.04), h = 1e-5
        let plus = try service.evaluate(law: p, deformationGradient: f.adding(direction.scaled(by: h)))
        let minus = try service.evaluate(law: p, deformationGradient: f.subtracting(direction.scaled(by: h)))
        let tangent = try service.tangent(law: p, deformationGradient: f, direction: direction)
        #expect(try ConstitutiveFixture.matrixNear(tangent.firstPiolaDirection, plus.firstPiolaStress.subtracting(minus.firstPiolaStress).scaled(by: 1/(2*h))))
        #expect(try ConstitutiveFixture.matrixNear(tangent.secondPiolaDirection, plus.secondPiolaStress.subtracting(minus.secondPiolaStress).scaled(by: 1/(2*h))))
        #expect(try ConstitutiveFixture.matrixNear(tangent.cauchyDirection, plus.cauchyStress.subtracting(minus.cauchyStress).scaled(by: 1/(2*h))))
        #expect(ConstitutiveFixture.near(tangent.energyDirection, (plus.energyDensity-minus.energyDensity)/(2*h), absolute: 1e-8))
    }
    @Test func superposedRigidRotationTransformsResponseAndTangent() throws {
        let p = try law(), angle = 0.7
        let rotation = try Matrix3(cos(angle),-sin(angle),0,sin(angle),cos(angle),0,0,0,1)
        let f = try Matrix3(1.1,0.2,0.01,0.03,0.9,0.02,0,0.04,1.05)
        let direction = try Matrix3(0.03,-0.02,0.01,0.01,0.02,-0.03,-0.02,0.01,0.04)
        let original = try service.evaluate(law: p, deformationGradient: f)
        let rotated = try service.evaluate(law: p, deformationGradient: rotation.multiplied(by: f))
        #expect(ConstitutiveFixture.near(original.energyDensity, rotated.energyDensity))
        #expect(try ConstitutiveFixture.matrixNear(rotated.secondPiolaStress, original.secondPiolaStress))
        #expect(try ConstitutiveFixture.matrixNear(rotated.firstPiolaStress, rotation.multiplied(by: original.firstPiolaStress)))
        #expect(try ConstitutiveFixture.matrixNear(rotated.cauchyStress, rotation.multiplied(by: original.cauchyStress).multiplied(by: rotation.transposed())))
        let tangent = try service.tangent(law: p, deformationGradient: f, direction: direction)
        let transformed = try service.tangent(law: p, deformationGradient: rotation.multiplied(by: f), direction: rotation.multiplied(by: direction))
        #expect(try ConstitutiveFixture.matrixNear(transformed.firstPiolaDirection, rotation.multiplied(by: tangent.firstPiolaDirection)))
        let rigid = try service.evaluate(law: p, deformationGradient: rotation)
        #expect(rigid.energyDensity < 1e-25)
        #expect(try ConstitutiveFixture.matrixNear(rigid.firstPiolaStress, .zero))
    }
    @Test func parameterOrientationCalibrationAndArithmeticRefusals() throws {
        let p = try law()
        #expect(throws: MaterialError.invalidParameter(name: "neoHookeanLaw")) { try NeoHookeanLaw(shearModulus: 0, lameLambda: 30, domain: p.domain) }
        #expect(throws: MaterialError.invalidParameter(name: "neoHookeanLaw")) { try NeoHookeanLaw(shearModulus: 20, lameLambda: -1, domain: p.domain) }
        #expect(throws: MaterialError.self) { try service.evaluate(law: p, deformationGradient: ConstitutiveFixture.diagonal(-1,1,1)) }
        #expect(throws: MaterialError.self) { try service.evaluate(law: p, deformationGradient: ConstitutiveFixture.diagonal(0,1,1)) }
        #expect(throws: MaterialError.self) { try service.evaluate(law: p, deformationGradient: ConstitutiveFixture.diagonal(0.1,1,1)) }
        #expect(throws: MaterialError.self) { try service.evaluate(law: p, deformationGradient: ConstitutiveFixture.diagonal(4,1,1)) }
        #expect(throws: MaterialError.self) { try service.tangent(law: p, deformationGradient: .identity, direction: ConstitutiveFixture.diagonal(1e308,1e308,1e308)) }
    }
}

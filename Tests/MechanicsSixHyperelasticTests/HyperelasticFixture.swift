import Testing
import SwiftMechanics
import Darwin

struct HyperelasticFixture {
    static func domain() throws -> StrainDomain { try StrainDomain(maximumStrainNorm: 5, minimumVolumeRatio: 0.1) }
    static func diagonal(_ a: Double, _ b: Double, _ c: Double) throws -> Matrix3 { try Matrix3(a,0,0,0,b,0,0,0,c) }
    static func shear(_ g: Double) throws -> Matrix3 { try Matrix3(1,g,0,0,1,0,0,0,1) }
    static func near(_ a: Double, _ b: Double, absolute: Double = 1e-10, relative: Double = 1e-7) -> Bool {
        abs(a-b) <= absolute+relative*max(abs(a),abs(b))
    }
    static func matrixNear(_ a: Matrix3, _ b: Matrix3, absolute: Double = 1e-8, relative: Double = 2e-6) throws -> Bool {
        for row in 0..<3 { for column in 0..<3 {
            if !near(try a.element(row: row,column: column), try b.element(row: row,column: column), absolute: absolute, relative: relative) { return false }
        }}
        return true
    }
    static func shearOracle(_ law: any HyperelasticResponding, expectedEnergy: Double, expectedDerivative: Double) throws {
        let r=try law.evaluate(deformationGradient: shear(0.2))
        #expect(near(r.energyDensity,expectedEnergy))
        #expect(near(r.firstPiolaStress.m01,0.4*expectedDerivative))
        #expect(near(r.cauchyStress.m01,0.4*expectedDerivative))
        #expect(near(r.cauchyStress.m00-r.cauchyStress.m11,0.08*expectedDerivative))
        #expect(r.energyDensity > 0)
        let zero=try law.evaluate(deformationGradient: .identity)
        #expect(zero.energyDensity == 0)
        #expect(try matrixNear(zero.firstPiolaStress,.zero))
    }
    static func volumeOracle(_ law: any HyperelasticResponding, expectedEnergy: Double, expectedPressure: Double) throws {
        let r=try law.evaluate(deformationGradient: diagonal(1.1,1.1,1.1)), j=1.1*1.1*1.1
        #expect(near(r.energyDensity,expectedEnergy))
        #expect(near(r.firstPiolaStress.m00,j*expectedPressure/1.1))
        #expect(try matrixNear(r.cauchyStress,diagonal(expectedPressure,expectedPressure,expectedPressure)))
    }
    static func tangentOracle(_ law: any HyperelasticResponding) throws {
        let f=try Matrix3(1.1,0.1,0.03,0.02,0.95,0.04,0,0.03,1.05)
        let d=try Matrix3(0.03,-0.02,0.01,0.01,0.02,-0.03,-0.02,0.01,0.04)
        let tangent=try law.tangent(deformationGradient: f,direction: d)
        let r=try law.evaluate(deformationGradient: f), p=r.firstPiolaStress
        let power=p.m00*d.m00+p.m01*d.m01+p.m02*d.m02+p.m10*d.m10+p.m11*d.m11+p.m12*d.m12+p.m20*d.m20+p.m21*d.m21+p.m22*d.m22
        for h in [1e-4,5e-5] {
            let plus=try law.evaluate(deformationGradient: f.adding(d.scaled(by: h)))
            let minus=try law.evaluate(deformationGradient: f.subtracting(d.scaled(by: h)))
            #expect(try matrixNear(tangent.firstPiolaDirection,plus.firstPiolaStress.subtracting(minus.firstPiolaStress).scaled(by: 1/(2*h)),absolute: 1e-7))
            #expect(try matrixNear(tangent.secondPiolaDirection.matrix(),plus.secondPiolaStress.matrix().subtracting(minus.secondPiolaStress.matrix()).scaled(by: 1/(2*h)),absolute: 1e-7))
            #expect(try matrixNear(tangent.cauchyDirection,plus.cauchyStress.subtracting(minus.cauchyStress).scaled(by: 1/(2*h)),absolute: 1e-7))
            #expect(near(power,(plus.energyDensity-minus.energyDensity)/(2*h),absolute: 1e-7,relative: 2e-6))
        }
    }
    static func objectivityOracle(_ law: any HyperelasticResponding) throws {
        let angle=0.7, q=try Matrix3(cos(angle),-sin(angle),0,sin(angle),cos(angle),0,0,0,1)
        let f=try Matrix3(1.1,0.2,0.01,0.03,0.9,0.02,0,0.04,1.05)
        let d=try Matrix3(0.03,-0.02,0.01,0.01,0.02,-0.03,-0.02,0.01,0.04)
        let original=try law.evaluate(deformationGradient: f), rotated=try law.evaluate(deformationGradient: q.multiplied(by: f))
        #expect(near(original.energyDensity,rotated.energyDensity))
        #expect(try matrixNear(rotated.secondPiolaStress.matrix(),original.secondPiolaStress.matrix()))
        #expect(try matrixNear(rotated.firstPiolaStress,q.multiplied(by: original.firstPiolaStress)))
        #expect(try matrixNear(rotated.cauchyStress,q.multiplied(by: original.cauchyStress).multiplied(by: q.transposed())))
        let tangent=try law.tangent(deformationGradient: f,direction: d)
        let transformed=try law.tangent(deformationGradient: q.multiplied(by: f),direction: q.multiplied(by: d))
        #expect(try matrixNear(transformed.firstPiolaDirection,q.multiplied(by: tangent.firstPiolaDirection)))
        #expect(try matrixNear(transformed.secondPiolaDirection.matrix(),tangent.secondPiolaDirection.matrix()))
        #expect(try matrixNear(transformed.cauchyDirection,q.multiplied(by: tangent.cauchyDirection).multiplied(by: q.transposed())))
        let rigid=try law.evaluate(deformationGradient: q)
        #expect(rigid.energyDensity < 1e-25)
        #expect(try matrixNear(rigid.firstPiolaStress,.zero))
    }
    static func failureOracle(_ law: any HyperelasticResponding) throws {
        #expect(throws: MaterialError.self) { try law.evaluate(deformationGradient: diagonal(0,1,1)) }
        #expect(throws: MaterialError.self) { try law.evaluate(deformationGradient: diagonal(-1,1,1)) }
        #expect(throws: MaterialError.self) { try law.evaluate(deformationGradient: diagonal(0.01,1,1)) }
        #expect(throws: MaterialError.self) { try law.evaluate(deformationGradient: diagonal(4,1,1)) }
        #expect(throws: MaterialError.self) { try law.tangent(deformationGradient: .identity,direction: diagonal(1e308,1e308,1e308)) }
        #expect(try law.evaluate(deformationGradient: .identity).energyDensity == 0)
    }
}

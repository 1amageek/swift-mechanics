#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

public struct NeoHookeanEvaluator: NeoHookeanEvaluating {
    public init() {}
    public func evaluate(law: NeoHookeanLaw, deformationGradient f: Matrix3) throws(MaterialError) -> NeoHookeanResponse {
        let kinematics = try FiniteStrainKinematics(deformationGradient: f, domain: law.domain)
        let logarithm = try finite(log(kinematics.volumeRatio))
        let coefficient = try finite(law.lameLambda*logarithm-law.shearModulus)
        let energy = try storedEnergy(law: law, deformation: f, logJ: logarithm)
        let stress = try core { () throws(CoreError) in
            let inverse = try f.inverted(relativeTolerance: 0)
            let inverseC = try inverse.multiplied(by: inverse.transposed())
            let s = try Matrix3.identity.scaled(by: law.shearModulus).adding(inverseC.scaled(by: coefficient))
            let p = try f.scaled(by: law.shearModulus).adding(inverse.transposed().scaled(by: coefficient))
            let cauchy = try p.multiplied(by: f.transposed()).scaled(by: 1/kinematics.volumeRatio)
            return (s,p,cauchy)
        }
        return NeoHookeanResponse(greenStrain: kinematics.greenStrain, volumeRatio: kinematics.volumeRatio,
            secondPiolaStress: stress.0, firstPiolaStress: stress.1, cauchyStress: stress.2, energyDensity: energy)
    }
    public func tangent(law: NeoHookeanLaw, deformationGradient f: Matrix3, direction h: Matrix3) throws(MaterialError) -> NeoHookeanDirectionalResponse {
        let response = try evaluate(law: law, deformationGradient: f)
        let inverse = try core { () throws(CoreError) in try f.inverted(relativeTolerance: 0) }
        let inverseH = try core { () throws(CoreError) in try inverse.multiplied(by: h) }
        let relativeJ = try finite(inverseH.m00+inverseH.m11+inverseH.m22)
        let coefficient = try finite(law.lameLambda*log(response.volumeRatio)-law.shearModulus)
        let coefficientDirection = try finite(law.lameLambda*relativeJ)
        let directions = try core { () throws(CoreError) in
            let inverseT = inverse.transposed()
            let dInverse = try inverse.multiplied(by: h).multiplied(by: inverse).scaled(by: -1)
            let inverseC = try inverse.multiplied(by: inverseT)
            let dInverseC = try dInverse.multiplied(by: inverseT).adding(inverse.multiplied(by: dInverse.transposed()))
            let ds = try inverseC.scaled(by: coefficientDirection).adding(dInverseC.scaled(by: coefficient))
            let dp = try h.scaled(by: law.shearModulus).adding(inverseT.scaled(by: coefficientDirection))
                .adding(dInverse.transposed().scaled(by: coefficient))
            let numerator = try dp.multiplied(by: f.transposed()).adding(response.firstPiolaStress.multiplied(by: h.transposed()))
            let dcauchy = try numerator.scaled(by: 1/response.volumeRatio).subtracting(response.cauchyStress.scaled(by: relativeJ))
            return (ds,dp,dcauchy)
        }
        let p = response.firstPiolaStress
        let energyDirection = try finite(p.m00*h.m00+p.m01*h.m01+p.m02*h.m02
            + p.m10*h.m10+p.m11*h.m11+p.m12*h.m12+p.m20*h.m20+p.m21*h.m21+p.m22*h.m22)
        return NeoHookeanDirectionalResponse(secondPiolaDirection: directions.0, firstPiolaDirection: directions.1,
            cauchyDirection: directions.2, energyDirection: energyDirection)
    }
    private func storedEnergy(law: NeoHookeanLaw, deformation f: Matrix3, logJ: Double) throws(MaterialError) -> Double {
        // Public fixed-size QR operations preserve tiny energy without trace/log cancellation.
        let factors = try core { () throws(CoreError) in
            let first = try Vector3(f.m00,f.m10,f.m20)
            let second = try Vector3(f.m01,f.m11,f.m21)
            let third = try Vector3(f.m02,f.m12,f.m22)
            let q1 = try first.normalized(), r11 = try first.magnitude()
            let r12 = try q1.dot(second), r13 = try q1.dot(third)
            let orthogonalSecond = try second.subtracting(q1.scaled(by: r12))
            let q2 = try orthogonalSecond.normalized(), r22 = try orthogonalSecond.magnitude()
            let q3 = try q1.cross(q2).normalized()
            let r23 = try q2.dot(third), r33 = try q3.dot(third)
            return (r11,r22,r33,r12,r13,r23)
        }
        guard factors.0 > 0, factors.1 > 0, factors.2 > 0 else { throw .invalidParameter(name: "unrepresentableNeoHookeanQR") }
        let distortion = try finite(diagonalEnergy(factors.0)+diagonalEnergy(factors.1)+diagonalEnergy(factors.2)
            + factors.3*factors.3+factors.4*factors.4+factors.5*factors.5)
        let energy = try finite((law.shearModulus/2)*distortion+(law.lameLambda/2)*logJ*logJ)
        guard energy >= 0 else { throw .nonFiniteResult(operation: "NeoHookeanEnergy") }
        return energy
    }
    private func diagonalEnergy(_ diagonal: Double) -> Double {
        let u = diagonal-1
        let remainder: Double
        if abs(u) < 0.125 {
            var term=u*u, sum=0.0
            for n in 2...25 { sum += term/Double(n); term *= -u }
            remainder=sum
        } else { remainder=u-log(diagonal) }
        return u*u+2*remainder
    }
    private func core<Result>(_ body: () throws(CoreError) -> Result) throws(MaterialError) -> Result {
        do { return try body() } catch { throw .core(error) }
    }
    private func finite(_ value: Double) throws(MaterialError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult(operation: "NeoHookean") }
        return value
    }
}

#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

internal struct InvariantHyperelasticKernel {
    let kinematics: FiniteStrainKinematics
    let inverseF: Matrix3
    let c: SymmetricTensor
    let inverseC: SymmetricTensor
    let i1: Double
    let i2: Double
    let a: Double
    let b: Double
    let x: Double
    let y: Double
    let gx: SymmetricTensor
    let gy: SymmetricTensor
    let gj: SymmetricTensor

    init(f: Matrix3, domain: StrainDomain) throws(MaterialError) {
        kinematics = try FiniteStrainKinematics(deformationGradient: f, domain: domain)
        let inverse = try ihCore { () throws(CoreError) in try f.inverted(relativeTolerance: 0) }
        inverseF = inverse
        c = try ihTensor(ihCore { () throws(CoreError) in try f.transposed().multiplied(by: f) })
        inverseC = try ihTensor(ihCore { () throws(CoreError) in try inverse.multiplied(by: inverse.transposed()) })
        i1 = try c.trace()
        i2 = try ihFinite(c.xx*c.yy+c.yy*c.zz+c.zz*c.xx-c.xy*c.xy-c.yz*c.yz-c.xz*c.xz)
        a = try ihFinite(exp(-2*log(kinematics.volumeRatio)/3)); b = try ihFinite(a*a)
        x = try Self.excess(f); y = try Self.excess(inverseF)
        gx = try SymmetricTensor.isotropic(2*a).subtracting(inverseC.scaled(by: 2*a*i1/3))
        gy = try SymmetricTensor.isotropic(2*b*i1).subtracting(c.scaled(by: 2*b))
            .subtracting(inverseC.scaled(by: 4*b*i2/3))
        gj = try inverseC.scaled(by: kinematics.volumeRatio)
    }

    func evaluate(_ potential: (Double,Double,Double) throws(MaterialError) -> InvariantEnergyDerivatives) throws(MaterialError) -> FiniteStressResponse {
        let w = try potential(x,y,kinematics.volumeRatio)
        return try kinematics.response(secondPiolaStress: stress(w), energyDensity: w.energy)
    }

    func tangent(h: Matrix3, potential: (Double,Double,Double) throws(MaterialError) -> InvariantEnergyDerivatives) throws(MaterialError) -> FiniteStressDirectionalResponse {
        let w = try potential(x,y,kinematics.volumeRatio)
        let f = kinematics.deformationGradient, j = kinematics.volumeRatio
        let dc = try ihTensor(ihCore { () throws(CoreError) in
            try f.transposed().multiplied(by: h).adding(h.transposed().multiplied(by: f))
        })
        let inverseMatrix = try inverseC.matrix(), directionMatrix = try dc.matrix()
        let da = try ihTensor(ihCore { () throws(CoreError) in
            try inverseMatrix.multiplied(by: directionMatrix).multiplied(by: inverseMatrix).scaled(by: -1)
        })
        let inverseH = try ihCore { () throws(CoreError) in try inverseF.multiplied(by: h) }
        let rj = try ihFinite(inverseH.m00+inverseH.m11+inverseH.m22)
        let dj = try ihFinite(j*rj), di1 = try dc.trace()
        let di2 = try ihFinite(i1*di1 - c.contracted(with: dc))
        let dx = try ihFinite(a*(di1 - 2*i1*rj/3))
        let dy = try ihFinite(b*(di2 - 4*i2*rj/3))
        let dgx = try gx.scaled(by: -2*rj/3)
            .subtracting(inverseC.scaled(by: 2*a*di1/3)).subtracting(da.scaled(by: 2*a*i1/3))
        let dgy = try gy.scaled(by: -4*rj/3).adding(SymmetricTensor.isotropic(2*b*di1))
            .subtracting(dc.scaled(by: 2*b)).subtracting(inverseC.scaled(by: 4*b*di2/3))
            .subtracting(da.scaled(by: 4*b*i2/3))
        let dgj = try inverseC.scaled(by: dj).adding(da.scaled(by: j))
        let dw1 = try ihFinite(w.w11*dx+w.w12*dy+w.w1j*dj)
        let dw2 = try ihFinite(w.w12*dx+w.w22*dy+w.w2j*dj)
        let dwj = try ihFinite(w.w1j*dx+w.w2j*dy+w.wjj*dj)
        let ds = try gx.scaled(by: dw1).adding(gy.scaled(by: dw2)).adding(gj.scaled(by: dwj))
            .adding(dgx.scaled(by: w.w1)).adding(dgy.scaled(by: w.w2)).adding(dgj.scaled(by: w.wj))
        return try kinematics.directionalResponse(deformationDirection: h, secondPiolaStress: stress(w), secondPiolaDirection: ds)
    }

    private func stress(_ w: InvariantEnergyDerivatives) throws(MaterialError) -> SymmetricTensor {
        try gx.scaled(by: w.w1).adding(gy.scaled(by: w.w2)).adding(gj.scaled(by: w.wj))
    }

    private static func excess(_ f: Matrix3) throws(MaterialError) -> Double {
        let qr = try ihCore { () throws(CoreError) in
            let u=try Vector3(f.m00,f.m10,f.m20), v=try Vector3(f.m01,f.m11,f.m21), w=try Vector3(f.m02,f.m12,f.m22)
            let q1=try u.normalized(), r1=try u.magnitude()
            let r12=try q1.dot(v), r13=try q1.dot(w)
            let orthogonal=try v.subtracting(q1.scaled(by: r12))
            let q2=try orthogonal.normalized(), r2=try orthogonal.magnitude()
            let q3=try q1.cross(q2).normalized()
            return (r1,r2,try q3.dot(w),r12,r13,try q2.dot(w))
        }
        guard qr.0 > 0, qr.1 > 0, qr.2 > 0 else { throw .invalidParameter(name: "invariantQR") }
        let l1=log(qr.0), l2=log(qr.1), l3=log(qr.2), mean=(l1+l2+l3)/3
        // Sum the nonnegative exponential remainders; linear diagonal terms cancel exactly in the mathematical invariant.
        let diagonal=ihExpRemainder(2*(l1-mean))+ihExpRemainder(2*(l2-mean))+ihExpRemainder(2*(l3-mean))
        let scale=exp(-mean), p=qr.3*scale, q=qr.4*scale, r=qr.5*scale
        return try ihFinite(diagonal+p*p+q*q+r*r)
    }
}

internal func ihCore<T>(_ body: () throws(CoreError) -> T) throws(MaterialError) -> T {
    do { return try body() } catch { throw .core(error) }
}
internal func ihFinite(_ value: Double) throws(MaterialError) -> Double {
    guard value.isFinite else { throw .nonFiniteResult(operation: "invariantHyperelasticity") }
    return value
}
internal func ihTensor(_ m: Matrix3) throws(MaterialError) -> SymmetricTensor {
    try SymmetricTensor(xx: m.m00, yy: m.m11, zz: m.m22,
                        xy: m.m01/2+m.m10/2, yz: m.m12/2+m.m21/2, xz: m.m02/2+m.m20/2)
}
internal func ihExpRemainder(_ x: Double) -> Double {
    if abs(x) >= 0.125 { return expm1(x)-x }
    var term=x*x/2, sum=term
    for n in 3...26 { term *= x/Double(n); sum += term }
    return sum
}

internal struct ContactNormalProduct {
    let force: Double
    let energy: Double
    let dissipation: Double
    let power: Double
    private static func coefficients(_ law: ContactNormalLaw) -> (k: Double, d: Double, p: Double, v: Double, linear: Bool, hc: Bool) {
        switch law {
        case .linear(let k,let d,let p,let v): return (k,d,p,v,true,false)
        case .hertz(let k,_,let p,let v): return (k,0,p,v,false,false)
        case .huntCrossley(let k,let d,_,let p,let v): return (k,d,p,v,false,true)
        }
    }
    static func admit(_ law: ContactNormalLaw, separation: Double, velocity: Double,
                      policy: ContactDerivativePolicy) throws(ContactDerivativeError) -> ContactDerivativeValidity {
        let c=coefficients(law)
        let slo=try ContactProductArithmetic.finite(separation-policy.separationRadius)
        let shi=try ContactProductArithmetic.finite(separation+policy.separationRadius)
        let vlo=try ContactProductArithmetic.finite(velocity-policy.normalSpeedRadius)
        let vhi=try ContactProductArithmetic.finite(velocity+policy.normalSpeedRadius)
        guard max(-slo,0) < c.p, max(abs(vlo),abs(vhi)) < c.v else { throw .outsideDomain }
        let branch: ContactDerivativeBranch
        if slo > 0 { branch = .separated }
        else {
            guard shi < 0 else { throw .nonsmoothBoundary }
            let dlo = -shi, dhi = -slo
            let elo=try ContactProductArithmetic.finite(c.linear ? c.k*dlo : c.k*dlo*dlo.squareRoot())
            let ehi=try ContactProductArithmetic.finite(c.linear ? c.k*dhi : c.k*dhi*dhi.squareRoot())
            let fmin: Double, fmax: Double
            if c.hc {
                let l=try ContactProductArithmetic.finite(1-c.d*vhi), h=try ContactProductArithmetic.finite(1-c.d*vlo)
                fmin=try ContactProductArithmetic.finite(min(elo*l,ehi*l)); fmax=try ContactProductArithmetic.finite(max(elo*h,ehi*h))
            } else {
                fmin=try ContactProductArithmetic.finite(elo-c.d*vhi); fmax=try ContactProductArithmetic.finite(ehi-c.d*vlo)
            }
            if fmin > 0 { branch = .compressive }
            else if fmax < 0 { branch = .clipped }
            else { throw .nonsmoothBoundary }
        }
        return ContactDerivativeValidity(branch:branch,minimumSeparation:slo,maximumSeparation:shi,
            minimumNormalVelocity:vlo,maximumNormalVelocity:vhi)
    }
    static func compute(_ law: ContactNormalLaw, separation: Double, velocity: Double,
                        separationDirection: Double, velocityDirection: Double,
                        branch: ContactDerivativeBranch) throws(ContactDerivativeError) -> ContactNormalProduct {
        if branch == .separated { return ContactNormalProduct(force:0,energy:0,dissipation:0,power:0) }
        let c=coefficients(law), delta = -separation, dd = -separationDirection
        let fe=try ContactProductArithmetic.finite(c.linear ? c.k*delta : c.k*delta*delta.squareRoot())
        let dfe=try ContactProductArithmetic.finite((c.linear ? c.k : 1.5*c.k*delta.squareRoot())*dd)
        let fn: Double, dfn: Double
        if branch == .clipped { fn=0; dfn=0 }
        else if c.hc {
            fn=try ContactProductArithmetic.finite(fe*(1-c.d*velocity))
            dfn=try ContactProductArithmetic.finite(dfe*(1-c.d*velocity)-fe*c.d*velocityDirection)
        } else {
            fn=try ContactProductArithmetic.finite(fe-c.d*velocity)
            dfn=try ContactProductArithmetic.finite(dfe-c.d*velocityDirection)
        }
        return try ContactNormalProduct(force:dfn,energy:ContactProductArithmetic.finite(fe*dd),
            dissipation:ContactProductArithmetic.finite((dfe-dfn)*velocity+(fe-fn)*velocityDirection),
            power:ContactProductArithmetic.finite(dfn*velocity+fn*velocityDirection))
    }
}

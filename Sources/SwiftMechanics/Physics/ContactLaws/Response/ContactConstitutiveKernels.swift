internal enum ContactConstitutiveKernels {
    static func normalResponse(_ law:ContactNormalLaw,separation:Double,velocity:Double) throws(ContactLawError) -> (Double,Double,Double,Double,Double,Double,Double) {
        let p:Double,v:Double,k:Double,d:Double,isLinear:Bool,isHC:Bool
        switch law {
        case .linear(let stiffness,let damping,let penetration,let speed): k=stiffness; d=damping; p=penetration; v=speed; isLinear=true; isHC=false
        case .hertz(let coefficient,_,let penetration,let speed): k=coefficient; d=0; p=penetration; v=speed; isLinear=false; isHC=false
        case .huntCrossley(let coefficient,let alpha,_,let penetration,let speed): k=coefficient; d=alpha; p=penetration; v=speed; isLinear=false; isHC=true
        }
        let delta=max(-separation,0)
        guard delta <= p, abs(velocity) <= v else { throw .normalDomain }
        if separation >= 0 { return (0,0,0,0,0,0,0) }
        let fe=try contactFinite(isLinear ? k*delta : k*delta*delta.squareRoot())
        let derivative=try contactFinite(isLinear ? k : 1.5*k*delta.squareRoot())
        let energy=try contactFinite((isLinear ? 0.5 : 0.4)*fe*delta)
        let unclipped=try contactFinite(isHC ? fe*(1-d*velocity) : fe-d*velocity)
        let force=max(unclipped,0)
        let derivativeP=unclipped > 0 ? try contactFinite(isHC ? derivative*(1-d*velocity) : derivative) : 0
        let derivativeV=unclipped > 0 ? try contactFinite(isHC ? -fe*d : -d) : 0
        let loss=try contactFinite((fe-force)*velocity)
        guard loss >= 0 else { throw .arithmeticFailure }
        return (force,energy,derivativeP,derivativeV,loss,fe,unclipped)
    }
    static func cohesiveResponse(_ law:ContactCohesionLaw,separation:Double) throws(ContactLawError) -> (Double,Double,Double) {
        switch law {
        case .none: return (0,0,0)
        case .reversibleLinear(let limit,let range):
            let openingWork=try contactFinite(0.5*limit*range)
            if separation < 0 { return (0,-openingWork,openingWork) }
            if separation >= range { return (0,0,openingWork) }
            let remainder=1-separation/range
            return (try contactFinite(-limit*remainder),try contactFinite(-openingWork*remainder*remainder),openingWork)
        }
    }
    static func squared(_ x:Double,_ y:Double) throws(ContactLawError) -> Double { try contactFinite(x*x+y*y) }
    static func magnitude(_ x:Double,_ y:Double) throws(ContactLawError) -> Double {
        try contactCore { () throws(CoreError) in try Vector3(x,y,0).magnitude() }
    }
    static func dot(_ x:Vector3,_ y:Vector3) throws(ContactLawError) -> Double {
        try contactCore { () throws(CoreError) in try x.dot(y) }
    }
    static func ellipse(_ x:Double,_ y:Double,first:Double,second:Double,load:Double) throws(ContactLawError) -> Double {
        let a=try contactFinite(first*load),b=try contactFinite(second*load)
        guard a > 0, b > 0 else { throw .arithmeticFailure }
        return try magnitude(contactFinite(x/a),contactFinite(y/b))
    }
    static func axes(_ basis:ContactBasis,normal:Double,first:Double,second:Double) throws(ContactLawError) -> Vector3 {
        try contactCore { () throws(CoreError) in
            try basis.normal.scaled(by:normal).adding(basis.firstTangent.scaled(by:first)).adding(basis.secondTangent.scaled(by:second))
        }
    }
    static func resistanceResponse(_ resistance:ContactResistanceParameters,load fn:Double,radius:Double,first w1:Double,second w2:Double,normal wn:Double) throws(ContactLawError) -> (Double,Double,Double,Double,Double,Double,Double,Double) {
        let rollingSpeed=try magnitude(w1,w2)
        let regularization=resistance.angularRegularization
        let rollingDenominator=try magnitude(rollingSpeed,regularization)
        let spinningDenominator=try magnitude(wn,regularization)
        let rollingLimit=try contactFinite(resistance.rollingCoefficient*fn*radius)
        let spinningLimit=try contactFinite(resistance.spinningCoefficient*fn*radius)
        let t1=try contactFinite(-rollingLimit*(w1/rollingDenominator))
        let t2=try contactFinite(-rollingLimit*(w2/rollingDenominator))
        let tn=try contactFinite(-spinningLimit*(wn/spinningDenominator))
        let resistanceD=try contactFinite(-t1*w1-t2*w2-tn*wn)
        guard resistanceD >= 0 else { throw .arithmeticFailure }
        return (t1,t2,tn,resistanceD,rollingDenominator,spinningDenominator,rollingLimit,spinningLimit)
    }
}

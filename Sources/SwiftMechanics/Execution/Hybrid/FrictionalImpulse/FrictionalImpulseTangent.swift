internal struct FrictionalImpulseTangent: Sendable {
    let values: [Double]
    let multiplier: Double
    let regime: FrictionalImpulseRegime

    @inline(never)
    static func solve(w: [Double], before: [Double], normal: Double, supplier: FrictionalImpulseSupplier,
                      policy: FrictionalImpulsePolicy, reserved: Int, work: inout NumericalWork) throws(FrictionalImpulseFailure) -> Self {
        let a=FrictionalImpulseArithmetic.self, impulseScale=policy.massScaleKg*policy.velocityScale
        try a.check(policy); try a.charge(64,&work)
        let aa=try a.finite(policy.massScaleKg*w[4]), dd=try a.finite(policy.massScaleKg*w[8])
        // Both original off-diagonal entries remain available for final full-row acceptance.
        let bb=try a.finite(0.5*(policy.massScaleKg*w[5])+0.5*(policy.massScaleKg*w[7]))
        guard aa > policy.tangentTolerance.pivotThreshold else { throw FrictionalImpulseFailure(.singularTangent) }
        let pivot=try a.finite(dd-(bb/aa)*bb)
        guard pivot > policy.tangentTolerance.pivotThreshold else { throw FrictionalImpulseFailure(.singularTangent) }
        if policy.coefficient == 0 { return Self(values:[0,0],multiplier:0,regime:.frictionless) }
        let radius=try a.finite(policy.coefficient*(normal/impulseScale))
        guard radius > 0 else { throw FrictionalImpulseFailure(.ambiguousBoundary) }
        let rhs=[try a.finite(-before[1]/policy.velocityScale),try a.finite(-before[2]/policy.velocityScale)]
        func shifted(_ shift: Double, _ ledger: inout NumericalWork) throws(FrictionalImpulseFailure) -> [Double] {
            try a.charge(2,&ledger)
            return try supplier.tangent([try a.finite(aa+shift),bb,bb,try a.finite(dd+shift)],rhs:rhs,policy:policy,reserved:reserved,work:&ledger)
        }
        let stick=try shifted(0,&work), stickNorm=try a.norm(stick)
        let tolerance=try a.threshold(policy.impulseTolerance,scale:radius)
        // FIXME(INCOMPLETE_IMPLEMENTATION): A tolerance-sized stick/slip boundary tie reaches this decision.
        // A separately specified tie law and evidence are required before choosing a regime at that boundary.
        guard abs(try a.finite(stickNorm-radius)) > tolerance else { throw FrictionalImpulseFailure(.ambiguousBoundary) }
        if stickNorm < radius {
            return Self(values:[try a.finite(stick[0]*impulseScale),try a.finite(stick[1]*impulseScale)],multiplier:0,regime:.sticking)
        }
        var low=0.0, high=max(1,max(aa,dd)), upper: [Double]?, bracketed=false
        for _ in 0..<policy.maximumBracketIterations {
            try a.check(policy); try a.iteration(&work); try a.charge(24,&work)
            let value=try shifted(high,&work)
            if try a.norm(value) <= radius { upper=value; bracketed=true; break }
            low=high; high=try a.finite(high*2)
        }
        guard bracketed, let initial=upper else { throw FrictionalImpulseFailure(.nonconvergence) }
        var chosen=initial, shift=high, converged=false
        for _ in 0..<policy.maximumBisectionIterations {
            try a.check(policy); try a.iteration(&work); try a.charge(32,&work)
            let middle=try a.finite(low+(high-low)*0.5)
            guard middle > low, middle < high else { throw FrictionalImpulseFailure(.nonconvergence) }
            let value=try shifted(middle,&work), magnitude=try a.norm(value)
            if magnitude > radius { low=middle }
            else { high=middle; chosen=value; shift=middle }
            // Always return the feasible side of the root; no radial rescaling changes the KKT solve.
            if abs(try a.finite(a.norm(chosen)-radius)) <= tolerance { converged=true; break }
        }
        guard converged, shift > 0 else { throw FrictionalImpulseFailure(.nonconvergence) }
        return Self(values:[try a.finite(chosen[0]*impulseScale),try a.finite(chosen[1]*impulseScale)],multiplier:shift,regime:.sliding)
    }
}

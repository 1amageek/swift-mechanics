internal enum BoundedPhaseOne {
    @inline(never)
    static func program(_ p: DenseConvexProgram,policy: OptimizationPolicy,work: inout NumericalWork) throws(OptimizationCause) -> DenseConvexProgram {
        let n=try OptimizationArithmetic.sum(p.n,1), a=try OptimizationArithmetic.sum(OptimizationArithmetic.product(2,p.r),p.userInequalities)
        let m=try OptimizationArithmetic.sum(a,OptimizationArithmetic.product(2,n))
        try OptimizationArithmetic.capacity("phaseOneVariables",n,policy.maximumVariables)
        try OptimizationArithmetic.capacity("phaseOneRows",m,policy.maximumRows)
        try OptimizationArithmetic.charge(try OptimizationArithmetic.sum(OptimizationArithmetic.product(m,n),OptimizationArithmetic.product(4,n)),policy:policy,work:&work)
        var midpoint=[Double](repeating:0,count:p.n), maximum=0.0
        for j in 0..<p.n { midpoint[j]=try OptimizationArithmetic.finite(0.5*p.lower[j]+0.5*p.upper[j]) }
        for i in 0..<p.r {
            maximum=max(maximum,abs(try OptimizationArithmetic.finite(OriginalConvexCertificate.row(p.equality,index:i,n:p.n,x:midpoint,policy:policy,work:&work)-p.equalityRHS[i])))
        }
        for i in 0..<p.userInequalities {
            maximum=max(maximum,try OptimizationArithmetic.finite(OriginalConvexCertificate.row(p.inequality,index:i,n:p.n,x:midpoint,policy:policy,work:&work)-p.inequalityRHS[i]))
        }
        var coefficients=[Double](repeating:0,count:try OptimizationArithmetic.product(m,n)), rhs=[Double](repeating:0,count:m)
        var cost=[Double](repeating:0,count:n); cost[p.n]=1
        for i in 0..<p.r {
            for j in 0..<p.n { coefficients[(2*i)*n+j]=p.equality[i*p.n+j]; coefficients[(2*i+1)*n+j] = -p.equality[i*p.n+j] }
            coefficients[(2*i)*n+p.n] = -1; coefficients[(2*i+1)*n+p.n] = -1
            rhs[2*i]=p.equalityRHS[i]; rhs[2*i+1] = -p.equalityRHS[i]
        }
        for i in 0..<p.userInequalities {
            for j in 0..<p.n { coefficients[(2*p.r+i)*n+j]=p.inequality[i*p.n+j] }
            coefficients[(2*p.r+i)*n+p.n] = -1; rhs[2*p.r+i]=p.inequalityRHS[i]
        }
        var lower=p.lower, upper=p.upper; lower.append(0); upper.append(maximum)
        for i in 0..<n {
            coefficients[(a+2*i)*n+i] = -1; coefficients[(a+2*i+1)*n+i] = 1
            rhs[a+2*i] = -lower[i]; rhs[a+2*i+1]=upper[i]
        }
        return DenseConvexProgram(n:n,r:0,m:m,userInequalities:a,cost:cost,constant:0,hessian:nil,equality:[],equalityRHS:[],
            inequality:coefficients,inequalityRHS:rhs,lower:lower,upper:upper)
    }
    @inline(never)
    static func farkas(original p: DenseConvexProgram,phase: OptimizationCertificate,policy: OptimizationPolicy,work: inout NumericalWork) throws(OptimizationCause) -> OptimizationInfeasibility {
        let relaxation=phase.point[p.n]
        guard relaxation > phase.primalThreshold else { throw .certificateRejected }
        try OptimizationArithmetic.charge(try OptimizationArithmetic.product(32,OptimizationArithmetic.sum(p.r,OptimizationArithmetic.sum(p.userInequalities,OptimizationArithmetic.product(2,p.n)))),policy:policy,work:&work)
        var equality=[Double](repeating:0,count:p.r), inequality=[Double](repeating:0,count:p.userInequalities)
        var lower=[Double](repeating:0,count:p.n), upper=lower, rhs=0.0, norm=0.0, scale=1.0
        for i in 0..<p.r { equality[i]=try OptimizationArithmetic.finite(phase.inequalityMultipliers[2*i]-phase.inequalityMultipliers[2*i+1]) }
        for i in 0..<p.userInequalities { inequality[i]=phase.inequalityMultipliers[2*p.r+i] }
        for i in 0..<p.n { lower[i]=phase.lowerMultipliers[i]; upper[i]=phase.upperMultipliers[i] }
        for i in 0..<p.r { rhs=try OptimizationArithmetic.finite(rhs+equality[i]*p.equalityRHS[i]); scale=max(scale,abs(equality[i])) }
        for i in 0..<p.userInequalities {
            guard inequality[i] >= 0 else { throw .certificateRejected }
            rhs=try OptimizationArithmetic.finite(rhs+inequality[i]*p.inequalityRHS[i]); scale=max(scale,inequality[i])
        }
        for i in 0..<p.n {
            guard lower[i] >= 0, upper[i] >= 0 else { throw .certificateRejected }
            rhs=try OptimizationArithmetic.finite(rhs-lower[i]*p.lower[i]+upper[i]*p.upper[i]); scale=max(scale,max(lower[i],upper[i]))
        }
        let threshold=try OptimizationArithmetic.threshold(max(scale,abs(rhs)),policy:policy)
        var boundedError=0.0
        for j in 0..<p.n {
            var value=upper[j]-lower[j]
            for i in 0..<p.r { try OptimizationArithmetic.charge(2,policy:policy,work:&work); value=try OptimizationArithmetic.finite(value+equality[i]*p.equality[i*p.n+j]) }
            for i in 0..<p.userInequalities { try OptimizationArithmetic.charge(2,policy:policy,work:&work); value=try OptimizationArithmetic.finite(value+inequality[i]*p.inequality[i*p.n+j]) }
            norm=max(norm,abs(value))
            boundedError=try OptimizationArithmetic.finite(boundedError+(abs(value)+threshold)*max(abs(p.lower[j]),abs(p.upper[j])))
        }
        let margin=try OptimizationArithmetic.finite(-rhs-boundedError)
        guard norm <= threshold, margin > threshold else { throw .certificateRejected }
        return OptimizationInfeasibility(equality:equality,inequality:inequality,lower:lower,upper:upper,residual:norm,rhs:rhs,threshold:threshold,boundedError:boundedError,margin:margin)
    }
}

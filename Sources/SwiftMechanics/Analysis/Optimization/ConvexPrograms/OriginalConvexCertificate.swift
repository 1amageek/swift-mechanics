internal enum OriginalConvexCertificate {
    @inline(never)
    static func assess(_ p: DenseConvexProgram,workspace: EnumerationWorkspace,policy: OptimizationPolicy,
        context: inout EnumerationContext,work: inout NumericalWork) throws(OptimizationCause) -> OptimizationCertificate? {
        let n=p.n
        try OptimizationArithmetic.charge(try OptimizationArithmetic.product(32,OptimizationArithmetic.sum(n,OptimizationArithmetic.sum(p.r,p.m))),policy:policy,work:&work)
        var primal=0.0, dual=0.0, stationarity=0.0, complementarity=0.0, primalScale=1.0, dualScale=1.0, stationarityScale=1.0, complementarityScale=1.0
        for i in 0..<p.r {
            let value=try row(p.equality,index:i,n:n,x:workspace.point,policy:policy,work:&work)
            primal=max(primal,abs(try OptimizationArithmetic.finite(value-p.equalityRHS[i])))
            primalScale=max(primalScale,max(abs(value),abs(p.equalityRHS[i])))
        }
        for i in 0..<p.m {
            let value=try row(p.inequality,index:i,n:n,x:workspace.point,policy:policy,work:&work)
            let slack=try OptimizationArithmetic.finite(value-p.inequalityRHS[i]), multiplier=workspace.inequalityDual[i]
            primal=max(primal,max(slack,0)); dual=max(dual,max(-multiplier,0))
            complementarity=max(complementarity,abs(try OptimizationArithmetic.finite(slack*multiplier)))
            primalScale=max(primalScale,max(abs(value),abs(p.inequalityRHS[i]))); dualScale=max(dualScale,abs(multiplier))
            complementarityScale=max(complementarityScale,try OptimizationArithmetic.finite(abs(multiplier)*max(1,max(abs(value),abs(p.inequalityRHS[i])))))
        }
        context.lastFeasibility=primal
        for j in 0..<n {
            var value=p.cost[j], localScale=abs(p.cost[j])
            if let h=p.hessian {
                let product=try row(h,index:j,n:n,x:workspace.point,policy:policy,work:&work)
                value=try OptimizationArithmetic.finite(value+product); localScale=try OptimizationArithmetic.finite(localScale+abs(product))
            }
            for i in 0..<p.r {
                try OptimizationArithmetic.charge(2,policy:policy,work:&work)
                let term=try OptimizationArithmetic.finite(p.equality[i*n+j]*workspace.equalityDual[i]); value=try OptimizationArithmetic.finite(value+term); localScale=try OptimizationArithmetic.finite(localScale+abs(term))
            }
            for i in 0..<p.m {
                try OptimizationArithmetic.charge(2,policy:policy,work:&work)
                let term=try OptimizationArithmetic.finite(p.inequality[i*n+j]*workspace.inequalityDual[i]); value=try OptimizationArithmetic.finite(value+term); localScale=try OptimizationArithmetic.finite(localScale+abs(term))
            }
            stationarity=max(stationarity,abs(value)); stationarityScale=max(stationarityScale,localScale)
        }
        let primalThreshold=try OptimizationArithmetic.threshold(primalScale,policy:policy), dualThreshold=try OptimizationArithmetic.threshold(dualScale,policy:policy)
        let stationarityThreshold=try OptimizationArithmetic.threshold(stationarityScale,policy:policy), complementarityThreshold=try OptimizationArithmetic.threshold(complementarityScale,policy:policy)
        guard primal <= primalThreshold, dual <= dualThreshold, stationarity <= stationarityThreshold, complementarity <= complementarityThreshold else { return nil }
        var objective=p.constant
        for i in 0..<n {
            try OptimizationArithmetic.charge(2,policy:policy,work:&work)
            objective=try OptimizationArithmetic.finite(objective+p.cost[i]*workspace.point[i])
            if let h=p.hessian { objective=try OptimizationArithmetic.finite(objective+0.5*workspace.point[i]*row(h,index:i,n:n,x:workspace.point,policy:policy,work:&work)) }
        }
        // Output-boundary copies retain a certified candidate across later workspace mutation.
        var lower=[Double](repeating:0,count:n), upper=lower, inequality=[Double](repeating:0,count:p.userInequalities)
        try OptimizationArithmetic.charge(try OptimizationArithmetic.sum(p.userInequalities,OptimizationArithmetic.product(2,n)),policy:policy,work:&work)
        for i in 0..<p.userInequalities { inequality[i]=workspace.inequalityDual[i] }
        for i in 0..<n { lower[i]=workspace.inequalityDual[p.userInequalities+2*i]; upper[i]=workspace.inequalityDual[p.userInequalities+2*i+1] }
        return OptimizationCertificate(point:workspace.point,objective:objective,equality:workspace.equalityDual,inequality:inequality,lower:lower,upper:upper,
            primal:primal,dual:dual,stationarity:stationarity,complementarity:complementarity,primalThreshold:primalThreshold,dualThreshold:dualThreshold,stationarityThreshold:stationarityThreshold,complementarityThreshold:complementarityThreshold)
    }
    static func row(_ a: [Double],index: Int,n: Int,x: [Double],policy: OptimizationPolicy,work: inout NumericalWork) throws(OptimizationCause) -> Double {
        try OptimizationArithmetic.charge(try OptimizationArithmetic.product(2,n),policy:policy,work:&work)
        var value=0.0
        for j in 0..<n { value=try OptimizationArithmetic.finite(value+a[index*n+j]*x[j]) }
        return value
    }
}

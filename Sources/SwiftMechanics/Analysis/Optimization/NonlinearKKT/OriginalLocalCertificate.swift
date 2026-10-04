internal enum OriginalLocalCertificate {
    @inline(never)
    static func assess(_ z: [Double],equations q: FixedActiveKKTEquations<Double>,policy: LocalOptimizationPolicy,context: inout LocalKKTContext,work: inout NumericalWork) throws(LocalOptimizationCause) -> LocalCertificateState {
        context.phase = .originalCertificate
        let n=q.layout.variableCount,r=q.layout.equalityCount,m=q.layout.inequalityCount,total=m+2*n,rows=r+q.active.count
        let x: [Double],v: NonlinearProgramValues<Double>,e: [Double]
        do {
            try q.validateDomain(at:z,work:&work)
            x=try q.primal(z,work:&work)
            e=try q.multipliers(z,work:&work).0
            v=try KKTProgramEvaluation.values(q.provider,layout:q.layout,point:x,original:true,scratch:q.scratch,cancelled:q.cancelled,work:&work)
        } catch { context.unavailable=KKTArithmetic.ledgerUnavailable(error); throw .callback(error) }
        try LocalKKTArithmetic.charge(try LocalKKTArithmetic.sum(LocalKKTArithmetic.product(32,total+r+n),LocalKKTArithmetic.product(rows,n)),policy:policy,work:&work)
        var mu=[Double](repeating:0,count:total),c=[Double](repeating:0,count:rows*n)
        for i in q.active.indices { mu[q.active[i]]=z[n+r+i] }
        var primal=0.0,dual=0.0,stationarity=0.0,complementarity=0.0,ps=1.0,ds=1.0,ss=1.0,cs=1.0
        for i in 0..<r { primal=max(primal,abs(v.equalities[i])); ps=max(ps,abs(v.equalities[i])) }
        for i in 0..<total {
            let value=try LocalKKTArithmetic.finite(q.inequalityValue(v,point:x,index:i))
            primal=max(primal,max(0,value)); dual=max(dual,max(0,-mu[i])); complementarity=max(complementarity,abs(try LocalKKTArithmetic.finite(value*mu[i])))
            ps=max(ps,abs(value)); ds=max(ds,abs(mu[i])); cs=max(cs,try LocalKKTArithmetic.finite(abs(mu[i])*max(1,abs(value))))
            var active=false
            for index in q.active { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); if index == i { active=true; break } }
            if active {
                primal=max(primal,abs(value))
                // FIXME(INCOMPLETE_IMPLEMENTATION): Weak-active critical-cone curvature is not implemented in this fixed-active proof.
                // Production callers with zero/small active multipliers must fail until the full critical cone is independently certified.
                guard mu[i] > policy.strictMultiplierMargin else { throw .weaklyActive(index:i,multiplier:mu[i]) }
            } else { guard value < -policy.inactiveSlackMargin else { throw .inactiveMargin(index:i,slack:value) } }
        }
        for j in 0..<n {
            var value=v.gradient[j],scale=abs(value)
            do {
                for i in 0..<r {
                    let a=try q.coefficient(v,equality:i,column:j,work:&work); c[i*n+j]=a
                    let term=try KKTArithmetic.finite(a*e[i]); value=try KKTArithmetic.finite(value+term); scale=try KKTArithmetic.finite(scale+abs(term))
                    try KKTArithmetic.charge(4,work:&work,cancelled:q.cancelled)
                }
                for i in q.active.indices {
                    let a=try q.inequalityCoefficient(v,index:q.active[i],column:j,work:&work); c[(r+i)*n+j]=a
                    let term=try KKTArithmetic.finite(a*mu[q.active[i]]); value=try KKTArithmetic.finite(value+term); scale=try KKTArithmetic.finite(scale+abs(term))
                    try KKTArithmetic.charge(4,work:&work,cancelled:q.cancelled)
                }
            } catch { throw .callback(error) }
            stationarity=max(stationarity,abs(value)); ss=max(ss,scale)
        }
        context.residual=max(primal,stationarity)
        let pt=try LocalKKTArithmetic.threshold(ps,policy:policy),dt=try LocalKKTArithmetic.threshold(ds,policy:policy),st=try LocalKKTArithmetic.threshold(ss,policy:policy),ct=try LocalKKTArithmetic.threshold(cs,policy:policy)
        guard primal <= pt,dual <= dt,stationarity <= st,complementarity <= ct else { throw .certificateRejected }
        return LocalCertificateState(point:x,equalities:e,inequalities:mu,values:v,activeJacobian:c,primal:primal,dual:dual,stationarity:stationarity,complementarity:complementarity,
            primalThreshold:pt,dualThreshold:dt,stationarityThreshold:st,complementarityThreshold:ct)
    }
}

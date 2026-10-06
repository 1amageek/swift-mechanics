internal enum StabilityOriginalEvidence {
    typealias Cause = NonlinearStabilityFailure.Cause
    struct Data {
        let gradient: [Double], reaction: [Double], balance: [Double], rows: [Double]
        let hessian: [Double], parameterDerivative: [Double]
        let energy: Double, arc: Double, derivativeError: Double
    }
    @inline(never)
    static func evaluate(_ s: NonlinearStabilitySource, z: [Double], predictor: [Double], direction: [Double],
                         forces: any StaticForceEvaluating<Double>, evaluator: any ConstraintEvaluating,
                         policy p: NonlinearStabilityPolicy, work: inout NumericalWork) throws(Cause) -> Data {
        try StabilityArithmetic.check(p)
        let n=s.count,d=s.dimension,model=s.model,S=model.chart.scales,E=model.energyScale,parameter=z[d-1]*p.parameterScale
        guard z.count==d,p.equilibrium.physicalForceTolerances.count==n else { throw .invalidInput }
        try StabilityArithmetic.finite(z)
        var q=[Double](repeating:0,count:n),gradient=q,reaction=q,balance=q,P=q
        for i in 0..<n { q[i]=z[i]*S[i]
            guard q[i]>=s.branch.minimumPosition[i],q[i]<=s.branch.maximumPosition[i] else { throw .outsideDomain }
        }
        let seed=work
        do { try forces.validate(model,point:z,parameter:parameter,work:&work) } catch { try StabilityArithmetic.prefix(seed,&work);throw .force(error) }
        try StabilityArithmetic.prefix(seed,&work)
        var H=[Double](repeating:0,count:try StabilityArithmetic.product(n,n))
        var rows:[Double]=[]
        if let c=s.constraints {
            let before=work,result:ConstraintEvaluation
            do { result=try evaluator.evaluate(c.system,position:q,velocity:[Double](repeating:0,count:n),time:s.time,policy:c.policy.evaluation,work:&work) }
            catch { try StabilityArithmetic.prefix(before,&work);throw .constraint(error) }
            try StabilityArithmetic.prefix(before,&work)
            guard result.layoutRevision==c.system.layout.revision,result.rowIDs==c.system.rows.map({$0.id}),
                result.values.count==s.rowCount,result.jacobian.count==s.rowCount*n else { throw .invalidSupplierOutput }
            rows=result.values
            try StabilityArithmetic.finite(rows);try StabilityArithmetic.finite(result.jacobian)
            for r in 0..<s.rowCount {
                var value=c.system.rows[r].constant
                for i in 0..<n { value+=c.system.rows[r].linear[i]*z[i]
                    guard abs(result.jacobian[r*n+i]-c.system.rows[r].linear[i])<=p.equilibrium.constraintTolerance else { throw .invalidSupplierOutput }
                    reaction[i]-=E/S[i]*result.jacobian[r*n+i]*z[n+r]
                }
                guard abs(rows[r])<=p.equilibrium.constraintTolerance,abs(rows[r]-value)<=p.equilibrium.constraintTolerance else { throw .originalResidualRejected }
            }
        }
        let before=work;let energy:Double
        do {
            for i in 0..<n {
                gradient[i]=try forces.gradient(model,point:z,parameter:parameter,coordinate:i,work:&work)
                P[i]=try forces.parameterDerivative(model,point:z,parameter:parameter,coordinate:i,work:&work)
                for j in 0..<n { H[i*n+j]=try forces.tangent(model,point:z,parameter:parameter,row:i,column:j,work:&work) }
            }
            energy=try forces.energy(model,point:z,parameter:parameter,work:&work)
        } catch { try StabilityArithmetic.prefix(before,&work);throw .force(error) }
        try StabilityArithmetic.prefix(before,&work)
        try StabilityArithmetic.finite(gradient);try StabilityArithmetic.finite(P);try StabilityArithmetic.finite(H)
        guard energy.isFinite else { throw .nonFiniteResult }
        try StabilityArithmetic.charge(try StabilityArithmetic.product(12,try StabilityArithmetic.product(n,n)),&work)
        for i in 0..<n { balance[i]=gradient[i]-reaction[i]
            guard balance[i].isFinite,abs(balance[i])<=p.equilibrium.physicalForceTolerances[i] else { throw .originalResidualRejected }
            for j in 0..<n { guard abs(H[i*n+j]-H[j*n+i])<=p.evidence.derivativeAbsoluteTolerances[i] else { throw .derivativeMismatch } }
        }
        var arc=direction[d-1]*(z[d-1]-predictor[d-1])
        for i in 0..<n { arc+=direction[i]*(z[i]-predictor[i]) }
        guard arc.isFinite,abs(arc)<=p.arcTolerance else { throw .originalResidualRejected }
        let error=try derivatives(s,z:z,H:H,P:P,g:gradient,forces:forces,policy:p,work:&work)
        try StabilityArithmetic.check(p)
        return Data(gradient:gradient,reaction:reaction,balance:balance,rows:rows,hessian:H,parameterDerivative:P,energy:energy,arc:arc,derivativeError:error)
    }
    @inline(never)
    private static func derivatives(_ s: NonlinearStabilitySource,z: [Double],H: [Double],P: [Double],g: [Double],
                                    forces: any StaticForceEvaluating<Double>, policy p: NonlinearStabilityPolicy,
                                    work: inout NumericalWork) throws(Cause) -> Double {
        let n=s.count,S=s.model.chart.scales,parameter=z[s.dimension-1]*p.parameterScale
        var plus=z,minus=z;var maximum=0.0
        for j in 0..<n {
            try StabilityArithmetic.check(p)
            let delta=p.evidence.displacementProbe*S[j]
            plus[j]=z[j]+p.evidence.displacementProbe;minus[j]=z[j]-p.evidence.displacementProbe
            let before=work
            for i in 0..<n {
                let gp=try StabilityArithmetic.force { () throws(StaticForceError) in try forces.gradient(s.model,point:plus,parameter:parameter,coordinate:i,work:&work) }
                let gm=try StabilityArithmetic.force { () throws(StaticForceError) in try forces.gradient(s.model,point:minus,parameter:parameter,coordinate:i,work:&work) }
                let numerical=(gp-gm)/(2*delta),e=abs(numerical-H[i*n+j])
                try check(e,scale:max(abs(numerical),abs(H[i*n+j])),index:i,policy:p);maximum=max(maximum,e)
            }
            let ep=try StabilityArithmetic.force { () throws(StaticForceError) in try forces.energy(s.model,point:plus,parameter:parameter,work:&work) }
            let em=try StabilityArithmetic.force { () throws(StaticForceError) in try forces.energy(s.model,point:minus,parameter:parameter,work:&work) }
            let numerical=(ep-em)/(2*delta),e=abs(numerical-g[j])
            try check(e,scale:max(abs(numerical),abs(g[j])),index:j,policy:p);maximum=max(maximum,e)
            try StabilityArithmetic.prefix(before,&work)
            plus[j]=z[j];minus[j]=z[j]
        }
        let before=work
        for i in 0..<n {
            let gp=try StabilityArithmetic.force { () throws(StaticForceError) in try forces.gradient(s.model,point:z,parameter:parameter+p.evidence.parameterProbe,coordinate:i,work:&work) }
            let gm=try StabilityArithmetic.force { () throws(StaticForceError) in try forces.gradient(s.model,point:z,parameter:parameter-p.evidence.parameterProbe,coordinate:i,work:&work) }
            let numerical=(gp-gm)/(2*p.evidence.parameterProbe),e=abs(numerical-P[i])
            try check(e,scale:max(abs(numerical),abs(P[i])),index:i,policy:p);maximum=max(maximum,e)
        }
        try StabilityArithmetic.prefix(before,&work)
        try StabilityArithmetic.charge(try StabilityArithmetic.product(12,try StabilityArithmetic.product(n,n)),&work)
        return maximum
    }
    private static func check(_ error: Double, scale: Double, index: Int, policy p: NonlinearStabilityPolicy) throws(Cause) {
        guard error.isFinite,scale.isFinite,error<=p.evidence.derivativeAbsoluteTolerances[index]+p.evidence.derivativeRelativeTolerance*scale else { throw .derivativeMismatch }
    }
}

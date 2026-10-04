public struct ExactConstraintDifferentiator: ConstraintDifferentiating {
    public init() {}
    @inline(never)
    public func direction(_ system: QuadraticConstraintSystem, position: [Double], velocity: [Double], time: Double,
                          direction d: ConstraintDirection, evaluationPolicy: ConstraintEvaluationPolicy, policy p: DerivativePolicy,
                          work w: inout NumericalWork) throws(DerivativeError) -> ConstraintTangent {
        try DifferentialArithmetic.checkpoint(p)
        let n=system.layout.scales.count, m=system.rows.count, nn=try DifferentialArithmetic.product(n,n)
        guard n <= p.maximumVelocities, m <= evaluationPolicy.maximumRows else { throw .capacityExceeded }
        guard d.layoutRevision == system.layout.revision else { throw .staleBinding }
        guard d.position.count == n, d.velocity.count == n, d.coefficients.count == m, d.time.isFinite else { throw .invalidShape }
        let reserved=try DifferentialArithmetic.product(m,try DifferentialArithmetic.sum(try DifferentialArithmetic.product(n,2),3))
        try DifferentialArithmetic.storage(reserved,&w)
        var nested: NumericalWork
        do { nested=NumericalWork(budget:try w.remainingBudget(reservedStorage:reserved)) } catch { throw .numerical(error) }
        let primal: ConstraintEvaluation
        do { primal=try QuadraticConstraintEvaluator().evaluate(system,position:position,velocity:velocity,time:time,policy:evaluationPolicy,work:&nested) }
        catch {
            do { try w.absorb(nested,reservedStorage:reserved) } catch { throw .numerical(error) }
            throw .constraints(error,failedSupplierWorkUnavailable:false)
        }
        do { try w.absorb(nested,reservedStorage:reserved) } catch { throw .numerical(error) }
        var dg=[Double](repeating:0,count:m), dj=[Double](repeating:0,count:m*n), dp=dj, dt=dg, db=dg
        let tau=try DifferentialArithmetic.scalar(time/system.layout.timeScale,d.time/system.layout.timeScale)
        try DifferentialArithmetic.charge(2,&w)
        for row in 0..<m {
            try DifferentialArithmetic.checkpoint(p)
            let c=system.rows[row], dc=d.coefficients[row]
            guard dc.rowID == c.id, dc.linear.count == n, dc.hessian.count == nn, dc.mixedTime.count == n else { throw .invalidShape }
            var value=try DifferentialArithmetic.scalar(c.constant,dc.constant)
            let bt=try DifferentialArithmetic.scalar(c.timeLinear,dc.timeLinear), qt=try DifferentialArithmetic.scalar(c.timeQuadratic,dc.timeQuadratic)
            let tau2=try DifferentialArithmetic.multiply(tau,tau,&w)
            value=try DifferentialArithmetic.add(value,DifferentialArithmetic.multiply(bt,tau,&w),&w)
            value=try DifferentialArithmetic.add(value,DifferentialArithmetic.multiply(DifferentialArithmetic.multiply(qt,tau2,&w),DifferentialArithmetic.scalar(0.5),&w),&w)
            var timeDerivative=try DifferentialArithmetic.add(bt,DifferentialArithmetic.multiply(qt,tau,&w),&w), bias=qt
            for i in 0..<n {
                try DifferentialArithmetic.charge(4,&w)
                let scale=system.layout.scales[i]
                let x=try DifferentialArithmetic.scalar(primal.normalizedPosition[i],d.position[i]/scale)
                let u=try DifferentialArithmetic.scalar(primal.normalizedVelocity[i],d.velocity[i]*system.layout.timeScale/scale)
                let a=try DifferentialArithmetic.scalar(c.linear[i],dc.linear[i]), e=try DifferentialArithmetic.scalar(c.mixedTime[i],dc.mixedTime[i])
                value=try DifferentialArithmetic.add(value,DifferentialArithmetic.multiply(a,x,&w),&w)
                value=try DifferentialArithmetic.add(value,DifferentialArithmetic.multiply(DifferentialArithmetic.multiply(tau,e,&w),x,&w),&w)
                timeDerivative=try DifferentialArithmetic.add(timeDerivative,DifferentialArithmetic.multiply(e,x,&w),&w)
                bias=try DifferentialArithmetic.add(bias,DifferentialArithmetic.multiply(DifferentialArithmetic.multiply(e,u,&w),DifferentialArithmetic.scalar(2),&w),&w)
                var ji=try DifferentialArithmetic.add(a,DifferentialArithmetic.multiply(tau,e,&w),&w)
                for j in 0..<n {
                    try DifferentialArithmetic.charge(1,&w)
                    guard dc.hessian[i*n+j] == dc.hessian[j*n+i] else { throw .invalidInput }
                    let h=try DifferentialArithmetic.scalar(c.hessian[i*n+j],dc.hessian[i*n+j])
                    try DifferentialArithmetic.charge(4,&w)
                    let xj=try DifferentialArithmetic.scalar(primal.normalizedPosition[j],d.position[j]/system.layout.scales[j])
                    let uj=try DifferentialArithmetic.scalar(primal.normalizedVelocity[j],d.velocity[j]*system.layout.timeScale/system.layout.scales[j])
                    value=try DifferentialArithmetic.add(value,DifferentialArithmetic.multiply(DifferentialArithmetic.multiply(DifferentialArithmetic.multiply(x,h,&w),xj,&w),DifferentialArithmetic.scalar(0.5),&w),&w)
                    ji=try DifferentialArithmetic.add(ji,DifferentialArithmetic.multiply(h,xj,&w),&w)
                    bias=try DifferentialArithmetic.add(bias,DifferentialArithmetic.multiply(DifferentialArithmetic.multiply(u,h,&w),uj,&w),&w)
                }
                dj[row*n+i]=ji.direction; try DifferentialArithmetic.charge(1,&w)
                dp[row*n+i]=try DifferentialArithmetic.finite(ji.direction/scale)
                try DifferentialArithmetic.equal(ji.value,primal.jacobian[row*n+i],p,&w)
            }
            dg[row]=value.direction; dt[row]=timeDerivative.direction; db[row]=bias.direction
            try DifferentialArithmetic.equal(value.value,primal.values[row],p,&w)
            try DifferentialArithmetic.equal(timeDerivative.value,primal.timeDerivative[row],p,&w)
            try DifferentialArithmetic.equal(bias.value,primal.accelerationBias[row],p,&w)
        }
        try DifferentialArithmetic.checkpoint(p)
        return ConstraintTangent(evaluation:primal,values:dg,normalizedJacobian:dj,physicalJacobian:dp,timeDerivative:dt,accelerationBias:db)
    }
}

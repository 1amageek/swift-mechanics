import MechanicsNumerics

public struct QuadraticConstraintEvaluator: ConstraintEvaluating {
    public init() {}
    @inline(never)
    public func evaluate(_ system: QuadraticConstraintSystem, position: [Double], velocity: [Double], time: Double,
                         policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(ConstraintError) -> ConstraintEvaluation {
        try validate(system,position:position,velocity:velocity,time:time,policy:policy,work:&work)
        let n=position.count, m=system.rows.count
        try ConstraintArithmetic.storage(ConstraintArithmetic.sum(ConstraintArithmetic.product(m,n),ConstraintArithmetic.sum(ConstraintArithmetic.product(2,n),ConstraintArithmetic.product(5,m))),&work)
        var x=[Double](repeating:0,count:n), u=x
        for i in 0..<n {
            try ConstraintArithmetic.charge(3,&work)
            x[i]=try ConstraintArithmetic.finite(position[i]/system.layout.scales[i])
            u[i]=try ConstraintArithmetic.finite(velocity[i]*system.layout.timeScale/system.layout.scales[i])
        }
        try ConstraintArithmetic.charge(1,&work)
        let tau=try ConstraintArithmetic.finite(time/system.layout.timeScale)
        var g=[Double](repeating:0,count:m), jt=g, bias=g, ids=[UInt64](repeating:0,count:m)
        var j=[Double](repeating:0,count:m*n)
        for row in 0..<m {
            try ConstraintArithmetic.check(policy)
            try evaluateRow(system.rows[row],x:x,u:u,tau:tau,row:row,g:&g,j:&j,jt:&jt,bias:&bias,work:&work)
            ids[row]=system.rows[row].id
        }
        try ConstraintArithmetic.check(policy)
        return ConstraintEvaluation(normalizedPosition:x,normalizedVelocity:u,values:g,jacobian:j,timeDerivative:jt,accelerationBias:bias,rowIDs:ids,layoutRevision:system.layout.revision)
    }
    @inline(never)
    internal func validate(_ system: QuadraticConstraintSystem, position: [Double], velocity: [Double], time: Double,
                          policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(ConstraintError) {
        try ConstraintArithmetic.check(policy)
        let n=system.layout.scales.count, m=system.rows.count
        guard n <= policy.maximumCoordinates, m <= policy.maximumRows else { throw .capacityExceeded }
        guard system.layout.revision == policy.expectedLayoutRevision else { throw .staleLayout }
        guard position.count == n, velocity.count == n else { throw .invalidDimensions }
        guard time.isFinite, time >= system.minimumTime, time <= system.maximumTime else { throw .outsideDomain }
        let square=try ConstraintArithmetic.product(n,n)
        for i in 0..<n {
            try ConstraintArithmetic.check(policy); try ConstraintArithmetic.charge(8,&work)
            guard system.layout.scales[i].isFinite, system.layout.scales[i] > 0, position[i].isFinite, velocity[i].isFinite,
                  system.minimumPosition[i].isFinite, system.maximumPosition[i].isFinite, system.minimumPosition[i] <= system.maximumPosition[i],
                  position[i] >= system.minimumPosition[i], position[i] <= system.maximumPosition[i] else { throw .outsideDomain }
            for k in 0..<i { try ConstraintArithmetic.charge(1,&work); guard system.layout.coordinateIDs[i] != system.layout.coordinateIDs[k] else { throw .invalidInput } }
        }
        for r in 0..<m {
            try ConstraintArithmetic.check(policy)
            let row=system.rows[r]
            guard row.linear.count == n, row.mixedTime.count == n, row.hessian.count == square else { throw .invalidDimensions }
            try ConstraintArithmetic.charge(3,&work)
            guard row.constant.isFinite, row.timeLinear.isFinite, row.timeQuadratic.isFinite else { throw .invalidInput }
            for k in 0..<r { try ConstraintArithmetic.charge(1,&work); guard row.id != system.rows[k].id else { throw .invalidInput } }
            for i in 0..<n {
                try ConstraintArithmetic.charge(2,&work)
                guard row.linear[i].isFinite, row.mixedTime[i].isFinite else { throw .invalidInput }
                for j in 0..<n {
                    try ConstraintArithmetic.charge(2,&work)
                    guard row.hessian[i*n+j].isFinite, row.hessian[i*n+j] == row.hessian[j*n+i] else { throw .invalidInput }
                }
            }
        }
    }
    @inline(never)
    private func evaluateRow(_ row: QuadraticConstraint, x: [Double], u: [Double], tau: Double, row r: Int,
                             g: inout [Double], j: inout [Double], jt: inout [Double], bias: inout [Double], work: inout NumericalWork) throws(ConstraintError) {
        let n=x.count
        try ConstraintArithmetic.charge(8,&work)
        var value=row.constant+row.timeLinear*tau+0.5*row.timeQuadratic*tau*tau
        var time=row.timeLinear+row.timeQuadratic*tau, acceleration=row.timeQuadratic
        for i in 0..<n {
            try ConstraintArithmetic.charge(12,&work)
            value+=row.linear[i]*x[i]+tau*row.mixedTime[i]*x[i]
            time+=row.mixedTime[i]*x[i]; acceleration+=2*row.mixedTime[i]*u[i]
            var gradient=row.linear[i]+tau*row.mixedTime[i]
            for k in 0..<n {
                try ConstraintArithmetic.charge(9,&work)
                let h=row.hessian[i*n+k]
                value+=0.5*x[i]*h*x[k]; gradient+=h*x[k]; acceleration+=u[i]*h*u[k]
            }
            j[r*n+i]=try ConstraintArithmetic.finite(gradient)
        }
        g[r]=try ConstraintArithmetic.finite(value); jt[r]=try ConstraintArithmetic.finite(time); bias[r]=try ConstraintArithmetic.finite(acceleration)
    }
}

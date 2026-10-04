
public struct WeightedConstraintAssembler: ConstraintAssembling, ConstraintRankAnalyzing, ActiveCoordinateRankAnalyzing {
    private let evaluator: any ConstraintEvaluating
    private let nonlinear: any NonlinearSolving<Double>
    private let linear: any LinearSolving<Double>
    public init(nonlinear: any NonlinearSolving<Double> = ReferenceNonlinearSolver<Double>(),
                linear: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) {
        self.evaluator=QuadraticConstraintEvaluator(); self.nonlinear=nonlinear; self.linear=linear
    }
    @inline(never)
    public func rank(_ sample: VelocityConstraintSample, activeCoordinates: [Int], policy: ConstraintSolvePolicy,
                     work: inout NumericalWork) throws(ConstraintError) -> ActiveCoordinateRankEvidence {
        let n=sample.layout.scales.count,m=sample.rowIDs.count,k=activeCoordinates.count
        guard k <= n else { throw .invalidDimensions }
        // Full retained input and restricted workspace are bounded before either is traversed.
        guard n <= policy.evaluation.maximumCoordinates,m <= policy.evaluation.maximumRows else { throw .capacityExceeded }
        let entries=try ConstraintArithmetic.product(m,k)
        let storage=try ConstraintArithmetic.sum(ConstraintArithmetic.product(2,entries),
            ConstraintArithmetic.sum(ConstraintArithmetic.product(3,n),ConstraintArithmetic.sum(ConstraintArithmetic.product(4,m),k)))
        try ConstraintArithmetic.storage(storage,&work)
        try admit(layout:sample.layout,rows:m,policy:policy,work:&work,allowEmptyRows:true)
        for i in activeCoordinates.indices {
            try ConstraintArithmetic.check(policy.evaluation);try ConstraintArithmetic.charge(1,&work)
            guard activeCoordinates[i] >= 0,activeCoordinates[i] < n else { throw .invalidDimensions }
            for j in 0..<i {
                try ConstraintArithmetic.charge(1,&work)
                guard activeCoordinates[j] != activeCoordinates[i] else { throw .invalidInput }
            }
        }
        try validateSample(sample,velocity:nil,policy:policy,work:&work)
        let rank=try ConstraintRowRank.compute(rows:sample.rows,ids:sample.rowIDs,metric:policy.diagonalMetric,
            policy:policy,work:&work,activeCoordinates:activeCoordinates)
        try ConstraintArithmetic.check(policy.evaluation)
        return ActiveCoordinateRankEvidence(sample:sample,activeCoordinates:activeCoordinates,policy:policy,rank:rank)
    }
    @inline(never)
    public func rank(_ sample: VelocityConstraintSample, policy: ConstraintSolvePolicy,
                     work: inout NumericalWork) throws(ConstraintError) -> ConstraintRankEvidence {
        let n=sample.layout.scales.count, m=sample.rowIDs.count
        try admit(layout:sample.layout,rows:m,policy:policy,work:&work)
        let entries=try ConstraintArithmetic.product(m,n)
        let storage=try ConstraintArithmetic.sum(ConstraintArithmetic.product(2,entries),
            ConstraintArithmetic.sum(ConstraintArithmetic.product(3,n),ConstraintArithmetic.product(4,m)))
        try ConstraintArithmetic.storage(storage,&work)
        try validateSample(sample,velocity:nil,policy:policy,work:&work)
        let result=try ConstraintRowRank.compute(rows:sample.rows,ids:sample.rowIDs,
            metric:policy.diagonalMetric,policy:policy,work:&work)
        try ConstraintArithmetic.check(policy.evaluation)
        return result
    }
    @inline(never)
    public func assemble(_ system: QuadraticConstraintSystem, initialPosition: [Double], time: Double,
                         policy: ConstraintSolvePolicy, work: inout NumericalWork) throws(ConstraintError) -> ConstraintAssemblySolution {
        let n=system.layout.scales.count, m=system.rows.count
        try admit(layout:system.layout,rows:m,policy:policy,work:&work)
        try reserve(n:n,m:m,work:&work)
        let zero=[Double](repeating:0,count:n)
        let before=try evaluator.evaluate(system,position:initialPosition,velocity:zero,time:time,policy:policy.evaluation,work:&work)
        try validateEvaluation(before,n:n,m:m,revision:system.layout.revision,work:&work)
        let rank=try ConstraintRowRank.compute(rows:before.jacobian,ids:before.rowIDs,metric:policy.diagonalMetric,policy:policy,work:&work)
        let solved=try solveAssembly(system,before:before,rank:rank,time:time,policy:policy,work:&work)
        return try finishAssembly(system,before:before,solved:solved,rank:rank,time:time,policy:policy,work:&work)
    }
    @inline(never)
    private func solveAssembly(_ system: QuadraticConstraintSystem, before: ConstraintEvaluation, rank: ConstraintRankEvidence, time: Double,
                               policy: ConstraintSolvePolicy, work: inout NumericalWork) throws(ConstraintError) -> NonlinearSolution<Double> {
        let n=before.normalizedPosition.count, total=try ConstraintArithmetic.sum(n,rank.rank)
        _=try ConstraintArithmetic.product(total,total)
        var initial=[Double](repeating:0,count:total)
        for i in 0..<n { initial[i]=before.normalizedPosition[i] }
        try ConstraintArithmetic.charge(1,&work)
        let equations=ConstraintKKTEquations<Double>(system:system,selected:rank.independentRows,reference:before.normalizedPosition,
            metric:policy.diagonalMetric,tau:time/system.layout.timeScale,evaluationPolicy:policy.evaluation)
        do { return try nonlinear.solve(equations,initialPoint:initial,policy:policy.nonlinear) } catch { throw .nonlinear(error) }
    }
    @inline(never)
    private func finishAssembly(_ system: QuadraticConstraintSystem, before: ConstraintEvaluation, solved: NonlinearSolution<Double>, rank: ConstraintRankEvidence,
                                time: Double, policy: ConstraintSolvePolicy, work: inout NumericalWork) throws(ConstraintError) -> ConstraintAssemblySolution {
        let n=system.layout.scales.count, m=system.rows.count
        guard solved.values.count == n+rank.rank else { throw .invalidDimensions }
        var q=[Double](repeating:0,count:n)
        let zero=[Double](repeating:0,count:n)
        for i in 0..<n { try ConstraintArithmetic.charge(1,&work); q[i]=try ConstraintArithmetic.finite(solved.values[i]*system.layout.scales[i]) }
        let after=try evaluator.evaluate(system,position:q,velocity:zero,time:time,policy:policy.evaluation,work:&work)
        try validateEvaluation(after,n:n,m:m,revision:system.layout.revision,work:&work)
        let finalRank=try ConstraintRowRank.compute(rows:after.jacobian,ids:after.rowIDs,metric:policy.diagonalMetric,policy:policy,work:&work)
        guard finalRank.independentRows == rank.independentRows else { throw .rankChanged }
        let residual=try original(after.values,ids:after.rowIDs,tolerance:policy.originalResidualTolerance,work:&work)
        let stationarity=try stationarity(before:before,after:after,solved:solved,rank:rank,policy:policy,work:&work)
        let correction=try correction(before.normalizedPosition,after.normalizedPosition,policy:policy,work:&work)
        try ConstraintArithmetic.charge(2,&work)
        let objective=try ConstraintArithmetic.finite(0.5*correction*correction)
        try ConstraintArithmetic.check(policy.evaluation)
        return ConstraintAssemblySolution(position:q,originalResidual:residual,stationarityResidual:stationarity,correctionNorm:correction,
            geometricObjective:objective,rank:finalRank,nonlinearDiagnostics:solved.diagnostics,responseWork:work)
    }
    @inline(never)
    private func stationarity(before: ConstraintEvaluation, after: ConstraintEvaluation, solved: NonlinearSolution<Double>, rank: ConstraintRankEvidence,
                              policy: ConstraintSolvePolicy, work: inout NumericalWork) throws(ConstraintError) -> Double {
        let n=before.normalizedPosition.count
        var result=0.0
        for i in 0..<n {
            try ConstraintArithmetic.charge(2,&work)
            var value=policy.diagonalMetric[i]*(after.normalizedPosition[i]-before.normalizedPosition[i])
            for k in 0..<rank.rank { try ConstraintArithmetic.charge(2,&work); value+=after.jacobian[rank.independentRows[k]*n+i]*solved.values[n+k] }
            result=max(result,abs(try ConstraintArithmetic.finite(value)))
        }
        guard result <= policy.originalResidualTolerance else { throw .inconsistent(rowID:0,residual:result) }
        return result
    }
    @inline(never)
    public func projectVelocity(_ sample: VelocityConstraintSample, initialVelocity: [Double], policy: ConstraintSolvePolicy,
                                work: inout NumericalWork, linearWork: inout NumericalWork) throws(ConstraintError) -> ConstraintVelocitySolution {
        let n=sample.layout.scales.count, m=sample.rowIDs.count
        do { try policy.linearCapability.validate(for:Double.self,algorithms:[.cholesky]) } catch { throw .numerical(error) }
        try admit(layout:sample.layout,rows:m,policy:policy,work:&work); try reserve(n:n,m:m,work:&work)
        try validateSample(sample,velocity:initialVelocity,policy:policy,work:&work)
        var u=[Double](repeating:0,count:n)
        for i in 0..<n { try ConstraintArithmetic.charge(2,&work); u[i]=try ConstraintArithmetic.finite(initialVelocity[i]*sample.layout.timeScale/sample.layout.scales[i]) }
        let rank=try ConstraintRowRank.compute(rows:sample.rows,ids:sample.rowIDs,metric:policy.diagonalMetric,policy:policy,work:&work)
        let corrected=try project(sample,u:u,rank:rank,policy:policy,work:&work,linearWork:&linearWork)
        return try finishVelocity(sample,before:u,after:corrected,rank:rank,policy:policy,work:&work,linearWork:linearWork)
    }
    @inline(never)
    private func project(_ sample: VelocityConstraintSample, u: [Double], rank: ConstraintRankEvidence, policy: ConstraintSolvePolicy,
                         work: inout NumericalWork, linearWork: inout NumericalWork) throws(ConstraintError) -> [Double] {
        let n=u.count, r=rank.rank
        if r == 0 { return u } // All original rows still undergo consistency acceptance.
        var matrix=[Double](repeating:0,count:r*r), rhs=[Double](repeating:0,count:r), output=u
        for i in 0..<r {
            let row=rank.independentRows[i]
            var value=sample.drift[row]
            for k in 0..<n { try ConstraintArithmetic.charge(2,&work); value+=sample.rows[row*n+k]*u[k] }
            rhs[i]=try ConstraintArithmetic.finite(value)
            for j in 0..<r {
                var entry=0.0
                for k in 0..<n { try ConstraintArithmetic.charge(3,&work); entry+=sample.rows[row*n+k]*sample.rows[rank.independentRows[j]*n+k]/policy.diagonalMetric[k] }
                matrix[i*r+j]=try ConstraintArithmetic.finite(entry)
            }
        }
        let solved=try solveGram(matrix,rhs:rhs,policy:policy,linearWork:&linearWork)
        guard solved.count == r else { throw .invalidDimensions }
        for i in 0..<n {
            var delta=0.0
            for k in 0..<r { try ConstraintArithmetic.charge(3,&work); delta+=sample.rows[rank.independentRows[k]*n+i]*solved[k]/policy.diagonalMetric[i] }
            try ConstraintArithmetic.charge(1,&work); output[i]=try ConstraintArithmetic.finite(u[i]-delta)
        }
        return output
    }
    @inline(never)
    private func solveGram(_ values: [Double], rhs: [Double], policy: ConstraintSolvePolicy, linearWork: inout NumericalWork) throws(ConstraintError) -> [Double] {
        let matrix: DenseMatrix<Double>, budget: NumericalBudget
        do { matrix=try DenseMatrix(rows:rhs.count,columns:rhs.count,values:values); budget=try linearWork.remainingBudget(reservedStorage:0) }
        catch { throw .numerical(error) }
        let solved: LinearSolution<Double>
        do { solved=try linear.solve(matrix,rightHandSide:rhs,capability:policy.linearCapability,tolerance:policy.linearTolerance,budget:budget) }
        catch { throw .linear(error,failedSupplierWorkUnavailable:true) }
        do { try linearWork.absorb(solved.diagnostics.work,reservedStorage:0) } catch { throw .numerical(error) }
        return solved.values
    }
    @inline(never)
    private func finishVelocity(_ sample: VelocityConstraintSample, before: [Double], after: [Double], rank: ConstraintRankEvidence, policy: ConstraintSolvePolicy,
                                work: inout NumericalWork, linearWork: NumericalWork) throws(ConstraintError) -> ConstraintVelocitySolution {
        let n=before.count, m=sample.rowIDs.count
        var residual=0.0, energy=0.0, velocity=[Double](repeating:0,count:n)
        for row in 0..<m {
            var value=sample.drift[row]
            for i in 0..<n { try ConstraintArithmetic.charge(2,&work); value+=sample.rows[row*n+i]*after[i] }
            value=try ConstraintArithmetic.finite(value)
            guard abs(value) <= policy.originalResidualTolerance else { throw .inconsistent(rowID:sample.rowIDs[row],residual:abs(value)) }
            residual=max(residual,abs(value))
        }
        for i in 0..<n {
            try ConstraintArithmetic.charge(9,&work)
            energy+=0.5*policy.energyScale*policy.diagonalMetric[i]*(after[i]*after[i]-before[i]*before[i])
            velocity[i]=try ConstraintArithmetic.finite(after[i]*sample.layout.scales[i]/sample.layout.timeScale)
        }
        energy=try ConstraintArithmetic.finite(energy)
        let norm=try correction(before,after,policy:policy,work:&work)
        try ConstraintArithmetic.check(policy.evaluation)
        return ConstraintVelocitySolution(velocity:velocity,originalResidual:residual,correctionNorm:norm,introducedKineticEnergy:energy,rank:rank,responseWork:work,linearWork:linearWork)
    }
    @inline(never)
    private func admit(layout: ConstraintCoordinateLayout, rows: Int, policy: ConstraintSolvePolicy, work: inout NumericalWork,
                       allowEmptyRows: Bool = false) throws(ConstraintError) {
        try ConstraintArithmetic.check(policy.evaluation)
        let n=layout.scales.count
        guard n <= policy.evaluation.maximumCoordinates, rows <= policy.evaluation.maximumRows else { throw .capacityExceeded }
        guard layout.revision == policy.evaluation.expectedLayoutRevision else { throw .staleLayout }
        guard policy.diagonalMetric.count == n, rows > 0 || allowEmptyRows else { throw .invalidDimensions }
        for i in 0..<n {
            try ConstraintArithmetic.check(policy.evaluation); try ConstraintArithmetic.charge(4,&work)
            guard policy.diagonalMetric[i].isFinite, policy.diagonalMetric[i] > 0, layout.scales[i].isFinite, layout.scales[i] > 0 else { throw .invalidInput }
            for j in 0..<i { try ConstraintArithmetic.charge(1,&work); guard layout.coordinateIDs[i] != layout.coordinateIDs[j] else { throw .invalidInput } }
        }
    }
    private func reserve(n: Int,m: Int,work: inout NumericalWork) throws(ConstraintError) {
        let rows=try ConstraintArithmetic.product(m,n), square=try ConstraintArithmetic.product(max(n,m),max(n,m))
        let count=try ConstraintArithmetic.sum(ConstraintArithmetic.product(6,rows),ConstraintArithmetic.sum(ConstraintArithmetic.product(3,square),ConstraintArithmetic.sum(ConstraintArithmetic.product(12,n),ConstraintArithmetic.product(8,m))))
        try ConstraintArithmetic.storage(count,&work)
    }
    @inline(never)
    private func validateSample(_ sample: VelocityConstraintSample, velocity: [Double]?, policy: ConstraintSolvePolicy, work: inout NumericalWork) throws(ConstraintError) {
        let n=sample.layout.scales.count, m=sample.rowIDs.count
        let entries=try ConstraintArithmetic.product(n,m)
        guard sample.rows.count == entries, sample.drift.count == m, sample.accelerationBias.count == m else { throw .invalidDimensions }
        if let velocity {
            guard velocity.count == n else { throw .invalidDimensions }
            for i in 0..<n { try ConstraintArithmetic.charge(1,&work); guard velocity[i].isFinite else { throw .invalidInput } }
        }
        for row in 0..<m {
            try ConstraintArithmetic.check(policy.evaluation); try ConstraintArithmetic.charge(2,&work)
            guard sample.drift[row].isFinite, sample.accelerationBias[row].isFinite else { throw .invalidInput }
            for j in 0..<row { try ConstraintArithmetic.charge(1,&work); guard sample.rowIDs[row] != sample.rowIDs[j] else { throw .invalidInput } }
            for i in 0..<n { try ConstraintArithmetic.charge(1,&work); guard sample.rows[row*n+i].isFinite else { throw .invalidInput } }
        }
    }
    @inline(never)
    private func validateEvaluation(_ value: ConstraintEvaluation, n: Int, m: Int, revision: UInt64, work: inout NumericalWork) throws(ConstraintError) {
        guard value.layoutRevision == revision, value.normalizedPosition.count == n, value.normalizedVelocity.count == n,
              value.values.count == m, value.jacobian.count == n*m, value.timeDerivative.count == m,
              value.accelerationBias.count == m, value.rowIDs.count == m else { throw .invalidDimensions }
        for x in value.normalizedPosition { try ConstraintArithmetic.charge(1,&work); guard x.isFinite else { throw .nonFiniteResult } }
        for x in value.values { try ConstraintArithmetic.charge(1,&work); guard x.isFinite else { throw .nonFiniteResult } }
        for x in value.jacobian { try ConstraintArithmetic.charge(1,&work); guard x.isFinite else { throw .nonFiniteResult } }
    }
    private func original(_ values: [Double], ids: [UInt64], tolerance: Double, work: inout NumericalWork) throws(ConstraintError) -> Double {
        var result=0.0
        for i in values.indices { try ConstraintArithmetic.charge(1,&work); guard abs(values[i]) <= tolerance else { throw .inconsistent(rowID:ids[i],residual:abs(values[i])) }; result=max(result,abs(values[i])) }
        return result
    }
    private func correction(_ before: [Double], _ after: [Double], policy: ConstraintSolvePolicy, work: inout NumericalWork) throws(ConstraintError) -> Double {
        var norm=0.0
        for i in before.indices { try ConstraintArithmetic.charge(4,&work); let delta=after[i]-before[i]; norm+=policy.diagonalMetric[i]*delta*delta }
        try ConstraintArithmetic.charge(1,&work); norm=try ConstraintArithmetic.finite(norm.squareRoot())
        guard norm <= policy.maximumCorrection else { throw .correctionExceeded(value:norm,limit:policy.maximumCorrection) }; return norm
    }
}

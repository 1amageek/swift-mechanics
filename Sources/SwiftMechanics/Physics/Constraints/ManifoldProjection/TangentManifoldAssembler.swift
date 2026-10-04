public struct TangentManifoldAssembler: ManifoldConstraintProjecting, Sendable {
    private let evaluator: any HolonomicGeometryProviding
    private let ranker: any ConstraintRankAnalyzing
    private let linear: any LinearSolving<Double>
    public init(evaluator:any HolonomicGeometryProviding = GeometricRelationEvaluator(),
                ranker:any ConstraintRankAnalyzing = WeightedConstraintAssembler(),linear:any LinearSolving<Double> = ReferenceLinearSolver<Double>()) {
        self.evaluator=evaluator;self.ranker=ranker;self.linear=linear
    }
    @inline(never)
    public func assemble(_ system:GeometricConstraintSystem,initial:KinematicState,policy:ManifoldProjectionPolicy,
                         work:inout NumericalWork) throws(ManifoldProjectionFailure) -> ManifoldAssemblyResult {
        var state=initial
        do throws(GeometricConstraintError) { return try run(system,state:&state,policy:policy,work:&work) }
        catch { throw ManifoldProjectionFailure(cause:error,position:state.q,work:work) }
    }
    @inline(never)
    private func run(_ system:GeometricConstraintSystem,state:inout KinematicState,policy:ManifoldProjectionPolicy,
                     work:inout NumericalWork) throws(GeometricConstraintError) -> ManifoldAssemblyResult {
        let n=system.layout.scales.count
        guard policy.constraints.diagonalMetric.count == n else { throw .invalidShape }
        // Check a caller-owned combined envelope before any workspace or supplier allocation.
        let reserve=try ManifoldArithmetic.numeric { () throws(NumericalError) -> Int in
            try NumericalWork.sum(system.scalarStorage,try NumericalWork.sum(try NumericalWork.product(8,try NumericalWork.product(system.rowIDs.count,system.rowIDs.count)),try NumericalWork.product(32,n)))
        }
        try ManifoldArithmetic.numeric { () throws(NumericalError) -> Void in try work.requireStorage(reserve) }
        _=try CompiledGeometricConfigurationValidator().snapshot(system,state:state,policy:policy.constraints.evaluation,work:&work)
        var path=0.0,initialRank:Int?=nil
        for iteration in 0...policy.maximumIterations {
            try ManifoldArithmetic.check(policy.constraints.evaluation)
            let geometry=try evaluation(system,state:state,policy:policy,reserve:reserve,work:&work)
            let rank=try rank(geometry.velocity,policy:policy,reserve:reserve,work:&work)
            if let value=initialRank { guard rank.rank == value else { throw .rankChanged } } else { initialRank=rank.rank }
            var residual=0.0
            for value in geometry.values { residual=max(residual,abs(value)) }
            for axis in geometry.alignmentResiduals { residual=max(residual,max(abs(axis.x),max(abs(axis.y),abs(axis.z)))) }
            if residual <= policy.constraints.originalResidualTolerance {
                try ManifoldArithmetic.check(policy.constraints.evaluation)
                return ManifoldAssemblyResult(state:state,geometry:geometry,residual:residual,path:path,iterations:iteration,rank:rank,metadata:policy.metadata,work:work)
            }
            guard iteration < policy.maximumIterations else { throw .iterationLimit }
            guard rank.rank > 0 else { throw .zeroRank }
            try ManifoldArithmetic.numeric { () throws(NumericalError) -> Void in try work.advanceIteration() }
            let delta=try correction(geometry,rank:rank,policy:policy,reserve:reserve,work:&work)
            var length=0.0
            for i in 0..<n { try ManifoldArithmetic.charge(3,&work);length+=policy.constraints.diagonalMetric[i]*delta[i]*delta[i] }
            path=try ManifoldArithmetic.finite(path+length.squareRoot())
            guard path <= policy.maximumPathCorrection else { throw .correctionExceeded(value:path,limit:policy.maximumPathCorrection) }
            state=try ManifoldRetraction.retract(system,state:state,dimensionlessTangent:delta,policy:policy.constraints.evaluation,work:&work)
        }
        throw .iterationLimit
    }
    private func seed(_ reserve:Int,work:inout NumericalWork) throws(GeometricConstraintError) -> NumericalWork {
        try ManifoldArithmetic.charge(1,&work)
        var local=try ManifoldArithmetic.numeric { () throws(NumericalError) -> NumericalWork in NumericalWork(budget:try work.remainingBudget(reservedStorage:reserve)) }
        try ManifoldArithmetic.charge(1,&local);return local
    }
    private func finish(_ local:NumericalWork,before:NumericalWork,reserve:Int,work:inout NumericalWork) throws(GeometricConstraintError) {
        guard local.budget == before.budget,local.operations >= before.operations,local.iterations >= before.iterations,
              local.peakScalarStorage >= before.peakScalarStorage else { throw .supplierLedgerReplaced }
        try ManifoldArithmetic.numeric { () throws(NumericalError) -> Void in try work.absorb(local,reservedStorage:reserve) }
    }
    @inline(never)
    private func evaluation(_ system:GeometricConstraintSystem,state:KinematicState,policy:ManifoldProjectionPolicy,reserve:Int,
                            work:inout NumericalWork) throws(GeometricConstraintError) -> HolonomicGeometrySample {
        var local=try seed(reserve,work:&work);let before=local
        var result:HolonomicGeometrySample?,failure:GeometricConstraintError?
        do throws(GeometricConstraintError) { result=try evaluator.evaluate(system,state:state,policy:policy.constraints.evaluation,work:&local) } catch { failure=error }
        try finish(local,before:before,reserve:reserve,work:&work)
        if let failure { throw failure }
        guard let result else { throw .invalidShape }
        return try GeometricOriginalAcceptance.validatedSample(result,system:system,state:state,tolerance:policy.constraints.originalResidualTolerance,
            policy:policy.constraints.evaluation,work:&work)
    }
    @inline(never)
    private func rank(_ sample:VelocityConstraintSample,policy:ManifoldProjectionPolicy,reserve:Int,
                      work:inout NumericalWork) throws(GeometricConstraintError) -> ConstraintRankEvidence {
        var local=try seed(reserve,work:&work);let before=local
        var result:ConstraintRankEvidence?,failure:ConstraintError?
        do throws(ConstraintError) { result=try ranker.rank(sample,policy:policy.constraints,work:&local) } catch { failure=error }
        try finish(local,before:before,reserve:reserve,work:&work)
        if let failure { throw .constraint(failure) }
        guard let result,result.rank >= 0,result.rank <= min(sample.layout.scales.count,sample.rowIDs.count),
              result.rank == result.independentRows.count,result.reactionNullity == sample.rowIDs.count-result.rank,
              result.dependentRowIDs.count == result.reactionNullity else { throw .invalidShape }
        for i in result.independentRows.indices {
            guard sample.rowIDs.indices.contains(result.independentRows[i]),!result.independentRows[..<i].contains(result.independentRows[i]) else { throw .invalidShape }
        }
        let expected=sample.rowIDs.indices.filter { !result.independentRows.contains($0) }.map { sample.rowIDs[$0] }
        guard expected == result.dependentRowIDs else { throw .invalidShape }
        // Independent builtin rank acceptance prevents supplied rank diagnostics from changing the retained basis.
        let original=try originalRank(sample,policy:policy.constraints,work:&work)
        guard result.rank == original.rank,result.independentRows == original.independentRows,result.dependentRowIDs == original.dependentRowIDs else { throw .rankChanged }
        return result
    }
    private func originalRank(_ sample:VelocityConstraintSample,policy:ConstraintSolvePolicy,work:inout NumericalWork) throws(GeometricConstraintError) -> ConstraintRankEvidence {
        do throws(ConstraintError) { return try WeightedConstraintAssembler().rank(sample,policy:policy,work:&work) }
        catch { throw .constraint(error) }
    }
    @inline(never)
    private func correction(_ geometry:HolonomicGeometrySample,rank:ConstraintRankEvidence,policy:ManifoldProjectionPolicy,
                            reserve:Int,work:inout NumericalWork) throws(GeometricConstraintError) -> [Double] {
        let n=geometry.source.v.count,r=rank.rank,a=geometry.velocity.rows,metric=policy.constraints.diagonalMetric
        var matrix=[Double](repeating:0,count:r*r),rhs=[Double](repeating:0,count:r)
        for i in 0..<r {
            rhs[i]=geometry.values[rank.independentRows[i]]
            for j in 0..<r { for k in 0..<n { try ManifoldArithmetic.charge(4,&work);matrix[i*r+j]+=a[rank.independentRows[i]*n+k]*a[rank.independentRows[j]*n+k]/metric[k] } }
        }
        try ManifoldArithmetic.charge(1,&work)
        let budget=try ManifoldArithmetic.numeric { () throws(NumericalError) -> NumericalBudget in try work.remainingBudget(reservedStorage:reserve) }
        let dense=try ManifoldArithmetic.numeric { () throws(NumericalError) -> DenseMatrix<Double> in try DenseMatrix<Double>(rows:r,columns:r,values:matrix) },solution:LinearSolution<Double>
        do throws(NumericalError) { solution=try linear.solve(dense,rightHandSide:rhs,capability:policy.constraints.linearCapability,tolerance:policy.constraints.linearTolerance,budget:budget) }
        catch { throw .supplierWorkUnavailable }
        guard solution.diagnostics.work.budget == budget,solution.diagnostics.work.operations > 0 else { throw .supplierLedgerReplaced }
        try ManifoldArithmetic.numeric { () throws(NumericalError) -> Void in try work.absorb(solution.diagnostics.work,reservedStorage:reserve) }
        guard solution.values.count == r,solution.values.allSatisfy({$0.isFinite}) else { throw .invalidShape }
        for i in 0..<r {
            var residual = -rhs[i],scale=abs(rhs[i])
            for j in 0..<r { try ManifoldArithmetic.charge(4,&work);let term=matrix[i*r+j]*solution.values[j];residual+=term;scale+=abs(term) }
            let tolerance=policy.constraints.linearTolerance
            guard residual.isFinite,scale.isFinite,abs(residual) <= tolerance.absoluteResidual+tolerance.relativeResidual*scale else { throw .originalRejected(row:geometry.velocity.rowIDs[rank.independentRows[i]]) }
        }
        var delta=[Double](repeating:0,count:n)
        for k in 0..<n { for j in 0..<r { try ManifoldArithmetic.charge(3,&work);delta[k]-=a[rank.independentRows[j]*n+k]*solution.values[j]/metric[k] };delta[k]=try ManifoldArithmetic.finite(delta[k]) }
        try ManifoldArithmetic.check(policy.constraints.evaluation);return delta
    }
}

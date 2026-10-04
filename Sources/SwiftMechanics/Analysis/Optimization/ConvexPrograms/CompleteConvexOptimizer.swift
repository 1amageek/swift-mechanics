public struct CompleteConvexOptimizer: OptimizationSolving, Sendable {
    private let linear: any LinearSolving<Double>
    public init(linear: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) { self.linear=linear }
    @inline(never)
    public func solve(_ problem: ConvexOptimizationProblem,policy: OptimizationPolicy,workspace: inout EnumerationWorkspace,
        work: inout NumericalWork) throws(OptimizationFailure) -> OptimizationResult {
        var context=EnumerationContext()
        do { return try run(problem,policy:policy,workspace:&workspace,context:&context,work:&work) }
        catch { throw OptimizationFailure(cause:error,phase:context.phase,work:work,processed:context.processed,residual:context.lastFeasibility,unavailable:context.failedSupplierWorkUnavailable,isPhaseOne:context.isPhaseOne) }
    }
    @inline(never)
    private func run(_ problem: ConvexOptimizationProblem,policy: OptimizationPolicy,workspace: inout EnumerationWorkspace,
        context: inout EnumerationContext,work: inout NumericalWork) throws(OptimizationCause) -> OptimizationResult {
        do { try policy.luCapability.validate(for:Double.self,algorithms:[.partialPivotLU]) } catch { throw .numerical(error) }
        let (p,reserved)=try DenseConvexAdmission.admit(problem,policy:policy,workspace:workspace,work:&work)
        try equalityAdmission(p,policy:policy,workspace:&workspace,context:&context,work:&work)
        if p.hessian != nil { try curvature(p,policy:policy,reserved:reserved,context:&context,work:&work) }
        if let best=try CompleteActiveEnumeration.run(p,solver:linear,policy:policy,reserved:reserved,workspace:&workspace,context:&context,work:&work) {
            return try publish(best,problem:problem,policy:policy,context:&context,work:&work)
        }
        context.phase = .phaseOne; context.isPhaseOne=true; context.lastFeasibility=nil
        let phase=try BoundedPhaseOne.program(p,policy:policy,work:&work)
        guard let certificate=try CompleteActiveEnumeration.run(phase,solver:linear,policy:policy,reserved:reserved,workspace:&workspace,context:&context,work:&work) else { throw .certificateRejected }
        let infeasibility=try BoundedPhaseOne.farkas(original:p,phase:certificate,policy:policy,work:&work)
        context.phase = .publication; try OptimizationArithmetic.check(policy)
        return OptimizationResult(metadata:problem.metadata,infeasibility:infeasibility,processed:context.processed)
    }
    @inline(never)
    private func equalityAdmission(_ p: DenseConvexProgram,policy: OptimizationPolicy,workspace: inout EnumerationWorkspace,
        context: inout EnumerationContext,work: inout NumericalWork) throws(OptimizationCause) {
        context.phase = .equalityRank
        try OptimizationArithmetic.charge(try OptimizationArithmetic.product(p.r,p.n),policy:policy,work:&work)
        workspace.rank=p.equality
        let rank=try ActiveRowRank.rank(rows:p.r,columns:p.n,buffer:&workspace.rank,policy:policy,work:&work)
        guard rank == p.r else { throw .dependentEqualityRows(rank:rank,rows:p.r) }
    }
    @inline(never)
    private func curvature(_ p: DenseConvexProgram,policy: OptimizationPolicy,reserved: Int,context: inout EnumerationContext,work: inout NumericalWork) throws(OptimizationCause) {
        context.phase = .curvature
        guard let values=p.hessian else { throw .invalidProblem }
        try OptimizationArithmetic.capacity("curvatureFactorEntries",try OptimizationArithmetic.product(p.n,p.n),policy.maximumFactorEntries)
        do { try policy.curvatureCapability.validate(for:Double.self,algorithms:[.cholesky]) } catch { throw .numerical(error) }
        let matrix: DenseMatrix<Double>
        do { matrix=try DenseMatrix(rows:p.n,columns:p.n,values:values) } catch { throw .numerical(error) }
        try OptimizationArithmetic.charge(p.n,policy:policy,work:&work)
        let rhs=[Double](repeating:0,count:p.n)
        _=try OptimizationLinearInvocation.solve(matrix,rhs:rhs,solver:linear,capability:policy.curvatureCapability,policy:policy,reserved:reserved,context:&context,work:&work)
    }
    private func publish(_ c: OptimizationCertificate,problem: ConvexOptimizationProblem,policy: OptimizationPolicy,
        context: inout EnumerationContext,work: inout NumericalWork) throws(OptimizationCause) -> OptimizationResult {
        context.phase = .publication
        try OptimizationArithmetic.charge(try OptimizationArithmetic.sum(c.point.count,1),policy:policy,work:&work)
        var point=[Double](repeating:0,count:c.point.count)
        for i in point.indices { point[i]=try OptimizationArithmetic.finite(c.point[i]*problem.metadata.variableReferences[i].magnitude) }
        let objective=try OptimizationArithmetic.finite(c.objective*problem.metadata.objectiveReference.magnitude)
        try OptimizationArithmetic.check(policy)
        return OptimizationResult(metadata:problem.metadata,optimum:c,physicalPoint:point,physicalObjective:objective,
            uniqueness:problem.hessian == nil ? .notEstablished : .strictConvexity,processed:context.processed)
    }
}

import MechanicsCore
import MechanicsModel
import MechanicsCompiler
import MechanicsNumerics
import MechanicsNonlinear
import MechanicsConstraints

public struct ReferenceEquilibriumSolver: EquilibriumSolving, Sendable {
    public let forces: any StaticForceEvaluating<Double>
    public let nonlinear: any NonlinearSolving<Double>
    public let assembly: any ConstraintAssembling
    public let evaluator: any ConstraintEvaluating
    public init(forces: any StaticForceEvaluating<Double> = ReferenceStaticForceEvaluator<Double>(), nonlinear: any NonlinearSolving<Double> = ReferenceNonlinearSolver<Double>(),
                assembly: any ConstraintAssembling = WeightedConstraintAssembler(), evaluator: any ConstraintEvaluating = QuadraticConstraintEvaluator()) {
        self.forces=forces; self.nonlinear=nonlinear; self.assembly=assembly; self.evaluator=evaluator
    }
    @inline(never)
    public func solve(_ model: StaticForceModel, constraints: StaticConstraints?, initialPosition: [Double], parameter: Double, time: Double,
                      branch: EquilibriumBranch, policy: EquilibriumPolicy, work: inout NumericalWork) throws(EquilibriumError)->EquilibriumSolution {
        let n=model.chart.count; let m=constraints?.system.rows.count ?? 0
        guard !policy.isCancelled() else { throw .cancelled }
        guard n<=policy.limits.coordinates,m<=policy.limits.rows,initialPosition.count==n,policy.physicalForceTolerances.count==n,
            branch.minimumPosition.count==n, time.isFinite else { throw .invalidInput }
        try boundedIdentity(model.identity,limit: policy.limits.identifierBytes)
        try boundedIdentity(model.chart.stamp.identity,limit: policy.limits.identifierBytes)
        try boundedIdentity(branch.identity,limit: policy.limits.identifierBytes)
        try equilibriumNumerics { () throws(NumericalError) in try policy.nonlinear.capability.validate(for: Double.self,algorithms: [.partialPivotLU]) }
        let reserve=try equilibriumNumerics { () throws(NumericalError) in try NumericalWork.sum(try NumericalWork.product(12,n),try NumericalWork.sum(try NumericalWork.product(2,try NumericalWork.product(m,n)),try NumericalWork.product(4,m))) }
        try equilibriumNumerics { () throws(NumericalError) in
            try work.requireStorage(reserve)
            let entries=try NumericalWork.product(m,try NumericalWork.product(n,n))
            try work.chargeOperations(try NumericalWork.sum(try NumericalWork.product(4,n),try NumericalWork.product(2,entries)))
        }
        for i in 0..<n {
            guard branch.minimumPosition[i]>=model.minimumPosition[i],branch.maximumPosition[i]<=model.maximumPosition[i],initialPosition[i].isFinite,
                initialPosition[i]>=branch.minimumPosition[i],initialPosition[i]<=branch.maximumPosition[i] else { throw .outsideDomain }
        }
        guard parameter.isFinite,parameter>=model.minimumParameter,parameter<=model.maximumParameter else { throw .outsideDomain }
        try boundedIdentity(model.parameterIdentity,limit:policy.limits.identifierBytes)
        try boundedIdentity(model.chart.frame.key,limit:policy.limits.identifierBytes)
        for joint in model.chart.joints { try boundedIdentity(joint.key,limit:policy.limits.identifierBytes) }
        if let c=constraints { try admit(c,model:model,policy:policy,time:time) }
        var seed=initialPosition
        var rank=ConstraintRankEvidence(rank:0,independentRows:[],dependentRowIDs:[],reactionNullity:0)
        if let c=constraints {
            let a=try assembled(c,position:seed,time:time,reserve:reserve,work:&work)
            guard a.position.count==n,a.rank.rank>=0,a.rank.rank<=n,a.rank.independentRows.count==a.rank.rank else { throw .invalidInput }
            for r in a.rank.independentRows { guard r>=0,r<m else { throw .invalidInput } }
            seed=a.position; rank=a.rank
            if case .requireUnique=policy.reactionSelection,rank.reactionNullity>0 { throw .reactionAmbiguity(nullity:rank.reactionNullity) }
        }
        let d=try equilibriumNumerics { () throws(NumericalError) in try NumericalWork.sum(n,rank.rank) }
        var initial=[Double](repeating:0,count:d)
        for i in 0..<n { initial[i]=seed[i]/model.chart.scales[i] }
        let equations=StaticKKTEquations<Double>(model:model,constraints:constraints?.system,independentRows:rank.independentRows,branch:branch,parameter:parameter,forces:forces,isCancelled:policy.isCancelled)
        let np=try limitedNonlinear(policy.nonlinear,work:work,reserved:reserve)
        let solution: NonlinearSolution<Double>
        do { solution=try nonlinear.solve(equations,initialPoint:initial,policy:np) }
        catch {
            try equilibriumNumerics { () throws(NumericalError) in try work.absorb(error.work,reservedStorage:reserve) }
            throw .nonlinear(error)
        }
        try equilibriumNumerics { () throws(NumericalError) in try work.absorb(solution.diagnostics.work,reservedStorage:reserve) }
        guard solution.values.count==d else { throw .invalidInput }
        var q=[Double](repeating:0,count:n)
        for i in 0..<n {
            q[i]=solution.values[i]*model.chart.scales[i]
            guard q[i].isFinite else { throw .nonFiniteResult }
            guard q[i]>=branch.minimumPosition[i],q[i]<=branch.maximumPosition[i] else { throw .outsideDomain }
            guard abs((q[i]-initialPosition[i])/model.chart.scales[i])<=branch.maximumNormalizedStep else { throw .branchExceeded }
        }
        var rowMu=[Double](repeating:0,count:m)
        for k in rank.independentRows.indices { rowMu[rank.independentRows[k]]=solution.values[n+k] }
        return try finish(model,constraints:constraints,position:q,normalized:solution.values,multipliers:rowMu,rank:rank,parameter:parameter,time:time,
            branch:branch,policy:policy,diagnostics:solution.diagnostics,reserve:reserve,work:&work)
    }
    private func admit(_ c:StaticConstraints,model:StaticForceModel,policy:EquilibriumPolicy,time:Double)throws(EquilibriumError) {
        let s=c.system; let n=model.chart.count
        guard s.layout.revision==model.chart.stamp.revision,c.policy.evaluation.expectedLayoutRevision==s.layout.revision else { throw .staleBinding }
        guard s.layout.coordinateIDs==model.chart.coordinateIDs,s.layout.dimensions==model.chart.dimensions,s.layout.scales==model.chart.scales,
            c.policy.evaluation.maximumCoordinates>=n,c.policy.evaluation.maximumRows>=s.rows.count,
            time>=s.minimumTime,time<=s.maximumTime else { throw .invalidInput }
        let nn=try equilibriumNumerics { () throws(NumericalError) in try NumericalWork.product(n,n) }
        for row in s.rows {
            guard row.linear.count==n,row.hessian.count==nn,row.mixedTime.count==n else { throw .invalidInput }
            // FIXME(INCOMPLETE_IMPLEMENTATION): Static solve currently admits affine time-independent retained rows only. Nonlinear, moving, or contact rows require original branch/tangent/reaction verification before admission.
            guard row.timeLinear==0,row.timeQuadratic==0,row.hessian.allSatisfy({$0==0}),row.mixedTime.allSatisfy({$0==0}) else { throw .unsupportedDomain }
        }
    }
    @inline(never)
    private func assembled(_ c:StaticConstraints,position:[Double],time:Double,reserve:Int,work:inout NumericalWork)throws(EquilibriumError)->ConstraintAssemblySolution {
        let p=c.policy
        let remaining=try equilibriumNumerics { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserve) }
        let responseCap=try equilibriumNumerics { () throws(NumericalError) in
            try NumericalBudget(scalarStorage:min(c.responseBudget.scalarStorage,remaining.scalarStorage),arithmeticOperations:min(c.responseBudget.arithmeticOperations,remaining.arithmeticOperations),iterations:min(c.responseBudget.iterations,remaining.iterations))
        }
        let npCap=try equilibriumNumerics { () throws(NumericalError) in
            try NumericalBudget(scalarStorage:remaining.scalarStorage-responseCap.scalarStorage,arithmeticOperations:remaining.arithmeticOperations-responseCap.arithmeticOperations,iterations:remaining.iterations-responseCap.iterations)
        }
        let budgetOwner=NumericalWork(budget:npCap)
        let np=try limitedNonlinear(p.nonlinear,work:budgetOwner,reserved:0)
        let cp:ConstraintSolvePolicy
        do { cp=try ConstraintSolvePolicy(evaluation:p.evaluation,diagonalMetric:p.diagonalMetric,energyScale:p.energyScale,rankPolicy:p.rankPolicy,
            rankRelativeTolerance:p.rankRelativeTolerance,originalResidualTolerance:p.originalResidualTolerance,maximumCorrection:p.maximumCorrection,
            nonlinear:np,linearCapability:p.linearCapability,linearTolerance:p.linearTolerance) } catch { throw .constraint(error) }
        try equilibriumNumerics { () throws(NumericalError) in
            try work.requireStorage(try NumericalWork.sum(reserve,try NumericalWork.sum(responseCap.scalarStorage,np.budget.scalarStorage)))
        }
        var response=NumericalWork(budget:responseCap)
        let value:ConstraintAssemblySolution
        do { value=try assembly.assemble(c.system,initialPosition:position,time:time,policy:cp,work:&response) }
        catch {
            try equilibriumNumerics { () throws(NumericalError) in try work.absorb(response,reservedStorage:reserve) }
            if case .nonlinear(let failure)=error {
                try equilibriumNumerics { () throws(NumericalError) in try work.absorb(failure.work,reservedStorage:try NumericalWork.sum(reserve,response.peakScalarStorage)) }
                throw .constraintFailure(error,failedSupplierWorkUnavailable:failure.failedSupplierWorkUnavailable)
            }
            throw .constraintFailure(error,failedSupplierWorkUnavailable:true)
        }
        try equilibriumNumerics { () throws(NumericalError) in
            try work.absorb(response,reservedStorage:reserve)
            try work.absorb(value.nonlinearDiagnostics.work,reservedStorage:try NumericalWork.sum(reserve,response.peakScalarStorage))
        }
        return value
    }
    @inline(never)
    private func originalConstraints(_ c:StaticConstraints,position:[Double],time:Double,reserve:Int,work:inout NumericalWork)throws(EquilibriumError)->ConstraintEvaluation {
        let remaining=try equilibriumNumerics { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserve) }
        let cap=try equilibriumNumerics { () throws(NumericalError) in
            try NumericalBudget(scalarStorage:min(c.responseBudget.scalarStorage,remaining.scalarStorage),arithmeticOperations:min(c.responseBudget.arithmeticOperations,remaining.arithmeticOperations),iterations:min(c.responseBudget.iterations,remaining.iterations))
        }
        try equilibriumNumerics { () throws(NumericalError) in try work.requireStorage(try NumericalWork.sum(reserve,cap.scalarStorage)) }
        var local=NumericalWork(budget:cap)
        let value:ConstraintEvaluation
        do { value=try evaluator.evaluate(c.system,position:position,velocity:[Double](repeating:0,count:position.count),time:time,policy:c.policy.evaluation,work:&local) }
        catch { try equilibriumNumerics { () throws(NumericalError) in try work.absorb(local,reservedStorage:reserve) };throw .constraint(error) }
        try equilibriumNumerics { () throws(NumericalError) in try work.absorb(local,reservedStorage:reserve) }
        let n=position.count;let m=c.system.rows.count
        guard value.values.count==m,value.jacobian.count == (try equilibriumNumerics { () throws(NumericalError) in try NumericalWork.product(m,n) }),value.layoutRevision==c.system.layout.revision else { throw .invalidInput }
        return value
    }
    @inline(never)
    private func finish(_ model:StaticForceModel,constraints:StaticConstraints?,position:[Double],normalized:[Double],multipliers:[Double],rank:ConstraintRankEvidence,parameter:Double,time:Double,
                        branch:EquilibriumBranch,policy:EquilibriumPolicy,diagnostics:NonlinearDiagnostics<Double>,reserve:Int,work:inout NumericalWork)throws(EquilibriumError)->EquilibriumSolution {
        let n=model.chart.count; var g=[Double](repeating:0,count:n); var reaction=g; var balance=g; var rows:[Double]=[]
        if let c=constraints {
            let verify=try assembled(c,position:position,time:time,reserve:reserve,work:&work)
            guard verify.rank.independentRows==rank.independentRows,verify.rank.reactionNullity==rank.reactionNullity else { throw .rankChanged }
            let value=try originalConstraints(c,position:position,time:time,reserve:reserve,work:&work)
            rows=value.values
            for r in rows.indices { guard abs(rows[r])<=policy.constraintTolerance else { throw .originalConstraint(row:r,residual:rows[r]) } }
            for i in 0..<n {
                var jt=0.0
                for r in multipliers.indices { jt += value.jacobian[r*n+i]*multipliers[r] }
                reaction[i] = -model.energyScale/model.chart.scales[i]*jt
            }
        }
        let energy:Double
        do {
            for i in 0..<n { g[i]=try forces.gradient(model,point:normalized,parameter:parameter,coordinate:i,work:&work) }
            energy=try forces.energy(model,point:normalized,parameter:parameter,work:&work)
        } catch { throw .force(error) }
        try equilibriumNumerics { () throws(NumericalError) in try work.chargeOperations(try NumericalWork.product(5,n)) }
        for i in 0..<n { balance[i]=g[i]-reaction[i]
            guard g[i].isFinite,reaction[i].isFinite,balance[i].isFinite else { throw .nonFiniteResult }
            guard abs(balance[i])<=policy.physicalForceTolerances[i] else { throw .originalBalance(coordinate:i,residual:balance[i]) }
        }
        guard energy.isFinite else { throw .nonFiniteResult }
        guard !policy.isCancelled() else { throw .cancelled }
        return EquilibriumSolution(model:model,constraints:constraints,branch:branch,parameter:parameter,time:time,position:position,physicalGradient:g,generalizedReaction:reaction,rowMultipliers:multipliers,
            originalForceResidual:balance,originalConstraintResidual:rows,energy:energy,rank:rank,nonlinearDiagnostics:diagnostics,work:work)
    }
}

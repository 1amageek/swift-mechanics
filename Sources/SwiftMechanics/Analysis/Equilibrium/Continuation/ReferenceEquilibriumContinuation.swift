
public struct ReferenceEquilibriumContinuation: EquilibriumContinuing, Sendable {
    public let solver: any EquilibriumSolving
    public init(solver:any EquilibriumSolving = ReferenceEquilibriumSolver()) { self.solver=solver }
    @inline(never)
    public func sweep(_ model:StaticForceModel,constraints:StaticConstraints?,branch:EquilibriumBranch,state:EquilibriumContinuationState,
                      cases:[EquilibriumLoadCase],policy:EquilibriumPolicy,work:inout NumericalWork)throws(EquilibriumError)->EquilibriumSweepReport {
        guard cases.count<=policy.limits.cases,model.chart.count<=policy.limits.coordinates,(constraints?.system.rows.count ?? 0)<=policy.limits.rows else { throw .capacityExceeded }
        try boundedIdentity(model.identity,limit:policy.limits.identifierBytes)
        try boundedIdentity(model.chart.stamp.identity,limit:policy.limits.identifierBytes)
        try boundedIdentity(model.parameterIdentity,limit:policy.limits.identifierBytes)
        try boundedIdentity(model.chart.frame.key,limit:policy.limits.identifierBytes)
        try boundedIdentity(branch.identity,limit:policy.limits.identifierBytes)
        for id in model.chart.joints { try boundedIdentity(id.key,limit:policy.limits.identifierBytes) }
        try boundedConstraints(constraints,n:model.chart.count,limits:policy.limits)
        try boundedConstraints(state.constraints,n:state.model.chart.count,limits:policy.limits)
        guard state.model==model,state.branch==branch,sameConstraints(state.constraints,constraints) else { throw .staleBinding }
        for i in cases.indices {
            try boundedIdentity(cases[i].identity,limit:policy.limits.identifierBytes)
            for j in 0..<i { guard cases[j].identity != cases[i].identity else { throw .invalidInput } }
        }
        // Stored result arrays plus seed and tangent provenance are reserved before any solve. Immutable input/model backing is shared by value.
        let reserve=try equilibriumNumerics { () throws(NumericalError) in
            let perCase=try NumericalWork.sum(try NumericalWork.product(16,model.chart.count),try NumericalWork.product(8,constraints?.system.rows.count ?? 0))
            return try NumericalWork.sum(model.chart.count,try NumericalWork.product(cases.count,perCase))
        }
        try equilibriumNumerics { () throws(NumericalError) in try work.requireStorage(reserve);try work.chargeOperations(cases.count) }
        var current=state;var reports:[EquilibriumCaseReport]=[];reports.reserveCapacity(cases.count)
        var attempted=0;var accepted=0;var stopped:EquilibriumError?
        for input in cases {
            let seed=current.position;let status:EquilibriumCaseStatus
            if let reason=stopped { status = .notAttempted(reason) }
            else if policy.isCancelled() { stopped = .cancelled;status = .notAttempted(.cancelled) }
            else if !input.parameter.isFinite || !input.time.isFinite || input.parameter<model.minimumParameter || input.parameter>model.maximumParameter { status = .failed(.outsideDomain) }
            else {
                attempted += 1
                var local=NumericalWork(budget:try equilibriumNumerics { () throws(NumericalError) in try work.remainingBudget(reservedStorage:reserve) })
                do {
                    let value=try solver.solve(model,constraints:constraints,initialPosition:seed,parameter:input.parameter,time:input.time,branch:branch,policy:policy,work:&local)
                    status = .accepted(value);current=EquilibriumContinuationState(solution:value);accepted += 1
                } catch {
                    status = .failed(error)
                    if mustStop(error) { stopped=error }
                }
                try equilibriumNumerics { () throws(NumericalError) in try work.absorb(local,reservedStorage:reserve) }
            }
            reports.append(EquilibriumCaseReport(input:input,stamp:model.chart.stamp,modelIdentity:model.identity,branchIdentity:branch.identity,suppliedSeed:seed,status:status))
        }
        return EquilibriumSweepReport(cases:reports,continuation:current,attemptedCases:attempted,acceptedCases:accepted,work:work)
    }
    private func boundedConstraints(_ value:StaticConstraints?,n:Int,limits:EquilibriumLimits)throws(EquilibriumError) {
        guard let value else { return }
        guard n<=limits.coordinates,value.system.rows.count<=limits.rows else { throw .capacityExceeded }
        let nn=try equilibriumNumerics { () throws(NumericalError) in try NumericalWork.product(n,n) }
        guard value.system.layout.scales.count==n,value.system.layout.coordinateIDs.count==n,value.system.layout.dimensions.count==n else { throw .invalidInput }
        for row in value.system.rows { guard row.linear.count==n,row.mixedTime.count==n,row.hessian.count==nn else { throw .invalidInput } }
    }
    private func sameConstraints(_ a:StaticConstraints?,_ b:StaticConstraints?)->Bool {
        switch (a,b) {
        case (nil,nil): return true
        case (.some(let a),.some(let b)):
            let x=a.system;let y=b.system
            guard x.layout.coordinateIDs==y.layout.coordinateIDs,x.layout.dimensions==y.layout.dimensions,x.layout.scales==y.layout.scales,x.layout.timeScale==y.layout.timeScale,
                x.layout.revision==y.layout.revision,x.minimumPosition==y.minimumPosition,x.maximumPosition==y.maximumPosition,x.minimumTime==y.minimumTime,x.maximumTime==y.maximumTime,x.rows.count==y.rows.count else { return false }
            for i in x.rows.indices { let r=x.rows[i];let s=y.rows[i]
                guard r.id==s.id,r.constant==s.constant,r.linear==s.linear,r.hessian==s.hessian,r.timeLinear==s.timeLinear,r.timeQuadratic==s.timeQuadratic,r.mixedTime==s.mixedTime else { return false }
            }
            return true
        default: return false
        }
    }
    private func numericalStop(_ e:NumericalError)->Bool {
        switch e { case .cancelled,.resourceLimit: true;default:false }
    }
    private func nonlinearStop(_ e:NonlinearFailure<Double>)->Bool {
        if e.failedSupplierWorkUnavailable { return true }
        if case .numerical(let n)=e.cause { return numericalStop(n) }
        return false
    }
    private func mustStop(_ e:EquilibriumError)->Bool {
        switch e {
        case .cancelled,.capacityExceeded: return true
        case .numerical(let n): return numericalStop(n)
        case .nonlinear(let n): return nonlinearStop(n)
        case .linear(_,let unknown): return unknown
        case .force(let f): if case .numerical(let n)=f { return numericalStop(n) };return false
        case .constraintFailure(let c,let unknown): return unknown || mustStop(.constraint(c))
        case .constraint(let c):
            switch c { case .cancelled,.capacityExceeded:return true;case .numerical(let n):return numericalStop(n);case .nonlinear(let n):return nonlinearStop(n);case .linear(let n,let unknown):return unknown || numericalStop(n);default:return false }
        default:return false
        }
    }
}

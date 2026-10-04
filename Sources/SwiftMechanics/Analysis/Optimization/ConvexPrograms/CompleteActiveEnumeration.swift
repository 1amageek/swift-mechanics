internal enum CompleteActiveEnumeration {
    @inline(never)
    static func run(_ p: DenseConvexProgram,solver: any LinearSolving<Double>,policy: OptimizationPolicy,reserved: Int,
        workspace: inout EnumerationWorkspace,context: inout EnumerationContext,work: inout NumericalWork) throws(OptimizationCause) -> OptimizationCertificate? {
        let n=p.n, maximum=n-p.r, minimum=p.hessian == nil ? maximum : 0
        guard maximum >= 0 else { throw .dependentEqualityRows(rank:n,rows:p.r) }
        var best: OptimizationCertificate?=nil
        for k in minimum...maximum {
            workspace.active.removeAll(keepingCapacity:true); workspace.active.reserveCapacity(k)
            for i in 0..<k { workspace.active.append(i) }
            var more=true
            while more {
                try OptimizationArithmetic.check(policy)
                guard context.processed < policy.maximumCandidateBases else { throw .nonconverged(processed:context.processed,limit:policy.maximumCandidateBases) }
                do { try work.advanceIteration() } catch { throw .numerical(error) }
                context.processed += 1; context.phase = .enumeration
                if try candidate(p,k:k,solver:solver,policy:policy,reserved:reserved,workspace:&workspace,context:&context,work:&work),
                    let certificate=try OriginalConvexCertificate.assess(p,workspace:workspace,policy:policy,context:&context,work:&work) {
                    if let existing=best { if certificate.objective < existing.objective { best=certificate } } else { best=certificate }
                }
                more=try nextCombination(k:k,m:p.m,indices:&workspace.active,policy:policy,work:&work)
            }
        }
        return best
    }
    @inline(never)
    private static func candidate(_ p: DenseConvexProgram,k: Int,solver: any LinearSolving<Double>,policy: OptimizationPolicy,reserved: Int,
        workspace: inout EnumerationWorkspace,context: inout EnumerationContext,work: inout NumericalWork) throws(OptimizationCause) -> Bool {
        let n=p.n, rows=p.r+k, d=n+rows
        let entries=try OptimizationArithmetic.product(d,d)
        try OptimizationArithmetic.capacity("factorEntries",entries,policy.maximumFactorEntries)
        try OptimizationArithmetic.charge(try OptimizationArithmetic.product(rows,n),policy:policy,work:&work)
        workspace.rank.removeAll(keepingCapacity:true); workspace.rank.reserveCapacity(try OptimizationArithmetic.product(rows,n))
        for i in 0..<p.r { for j in 0..<n { workspace.rank.append(p.equality[i*n+j]) } }
        for index in workspace.active { for j in 0..<n { workspace.rank.append(p.inequality[index*n+j]) } }
        let rank=try ActiveRowRank.rank(rows:rows,columns:n,buffer:&workspace.rank,policy:policy,work:&work)
        if rank < rows { return false }
        try OptimizationArithmetic.charge(try OptimizationArithmetic.sum(OptimizationArithmetic.product(4,entries),OptimizationArithmetic.product(4,d)),policy:policy,work:&work)
        workspace.kkt.removeAll(keepingCapacity:true); workspace.kkt.reserveCapacity(entries)
        for _ in 0..<entries { workspace.kkt.append(0) }
        workspace.rhs.removeAll(keepingCapacity:true); workspace.rhs.reserveCapacity(d)
        for i in 0..<n { workspace.rhs.append(-p.cost[i]) }
        for value in p.equalityRHS { workspace.rhs.append(value) }
        for index in workspace.active { workspace.rhs.append(p.inequalityRHS[index]) }
        if let h=p.hessian { for i in 0..<n { for j in 0..<n { workspace.kkt[i*d+j]=h[i*n+j] } } }
        for i in 0..<rows { for j in 0..<n {
            let coefficient=i < p.r ? p.equality[i*n+j] : p.inequality[workspace.active[i-p.r]*n+j]
            workspace.kkt[(n+i)*d+j]=coefficient; workspace.kkt[j*d+n+i]=coefficient
        } }
        let matrix: DenseMatrix<Double>
        do { matrix=try DenseMatrix(rows:d,columns:d,values:workspace.kkt) } catch { throw .numerical(error) }
        let solution=try OptimizationLinearInvocation.solve(matrix,rhs:workspace.rhs,solver:solver,capability:policy.luCapability,
            policy:policy,reserved:reserved,context:&context,work:&work)
        context.phase = .originalCertificate
        try OptimizationArithmetic.charge(try OptimizationArithmetic.sum(d,p.m),policy:policy,work:&work)
        workspace.point.removeAll(keepingCapacity:true); workspace.equalityDual.removeAll(keepingCapacity:true); workspace.inequalityDual.removeAll(keepingCapacity:true)
        workspace.point.reserveCapacity(n); workspace.equalityDual.reserveCapacity(p.r); workspace.inequalityDual.reserveCapacity(p.m)
        for i in 0..<n { workspace.point.append(solution.values[i]) }
        for i in 0..<p.r { workspace.equalityDual.append(solution.values[n+i]) }
        for _ in 0..<p.m { workspace.inequalityDual.append(0) }
        for i in 0..<k { workspace.inequalityDual[workspace.active[i]]=solution.values[n+p.r+i] }
        return true
    }
    private static func nextCombination(k: Int,m: Int,indices: inout [Int],policy: OptimizationPolicy,work: inout NumericalWork) throws(OptimizationCause) -> Bool {
        if k == 0 { return false }
        try OptimizationArithmetic.charge(try OptimizationArithmetic.product(2,k),policy:policy,work:&work)
        for i in stride(from:k-1,through:0,by:-1) {
            if indices[i] < m-k+i {
                indices[i] += 1
                if i+1 < k { for j in (i+1)..<k { indices[j]=indices[j-1]+1 } }
                return true
            }
        }
        return false
    }
}

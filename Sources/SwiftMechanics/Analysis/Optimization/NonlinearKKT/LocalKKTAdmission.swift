internal enum LocalKKTAdmission {
    @inline(never)
    static func admit(_ p: FixedActiveNonlinearProblem,policy: LocalOptimizationPolicy,work: inout NumericalWork) throws(LocalOptimizationCause) -> (NonlinearProgramLayout,Int) {
        do { try KKTArithmetic.check(policy.isCancelled) } catch { throw .callback(error) }
        let l=p.provider.layout,n=l.variableCount,r=l.equalityCount,m=l.inequalityCount
        guard n > 0,l.metadata.variableReferences.count == n,p.lowerBounds.count == n,p.upperBounds.count == n,p.initialPoint.count == n,
            p.initialEqualityMultipliers.count == r,p.initialActiveMultipliers.count == p.activeInequalities.count else { throw .invalidProblem }
        let rows=try LocalKKTArithmetic.sum(r,LocalKKTArithmetic.sum(m,LocalKKTArithmetic.product(2,n))),d=try LocalKKTArithmetic.sum(n,LocalKKTArithmetic.sum(r,p.activeInequalities.count))
        try LocalKKTArithmetic.capacity(n,policy.maximumVariables); try LocalKKTArithmetic.capacity(rows,policy.maximumRows)
        try LocalKKTArithmetic.capacity(try LocalKKTArithmetic.product(d,d),policy.maximumDenseEntries)
        let nnz=try LocalKKTArithmetic.sum(l.equalityJacobian.columnIndices.count,LocalKKTArithmetic.sum(l.inequalityJacobian.columnIndices.count,l.lagrangianHessian.columnIndices.count))
        try LocalKKTArithmetic.capacity(nnz,policy.maximumNonzeros)
        var reserved=try LocalKKTArithmetic.sum(LocalKKTArithmetic.product(16,LocalKKTArithmetic.product(d,d)),LocalKKTArithmetic.product(40,LocalKKTArithmetic.sum(rows,d)))
        reserved=try LocalKKTArithmetic.sum(reserved,LocalKKTArithmetic.sum(LocalKKTArithmetic.product(4,nnz),policy.maximumProviderScratchScalars))
        do { try work.requireStorage(reserved) } catch { throw .numerical(error) }
        try pattern(l.equalityJacobian,rows:r,columns:n,policy:policy,work:&work)
        try pattern(l.inequalityJacobian,rows:m,columns:n,policy:policy,work:&work)
        try pattern(l.lagrangianHessian,rows:n,columns:n,policy:policy,work:&work)
        for _ in l.metadata.identity.utf8 { try LocalKKTArithmetic.charge(2,policy:policy,work:&work) }
        for _ in l.metadata.provenance.source.utf8 { try LocalKKTArithmetic.charge(2,policy:policy,work:&work) }
        for ref in l.metadata.variableReferences { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); guard ref.magnitude > 0 else { throw .invalidProblem } }
        for ref in l.metadata.equalityReferences { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); guard ref.magnitude > 0 else { throw .invalidProblem } }
        for ref in l.metadata.inequalityReferences { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); guard ref.magnitude > 0 else { throw .invalidProblem } }
        guard l.metadata.objectiveReference.magnitude > 0 else { throw .invalidProblem }
        for i in 0..<n {
            try LocalKKTArithmetic.charge(6,policy:policy,work:&work)
            // FIXME(INCOMPLETE_IMPLEMENTATION): This published solver admits finite boxes only.
            // Infinite-bound callers must fail until an independently qualified recession/domain method is implemented.
            guard p.lowerBounds[i].isFinite,p.upperBounds[i].isFinite else { throw .unsupportedDomain }
            guard p.lowerBounds[i] <= p.upperBounds[i],p.initialPoint[i].isFinite else { throw .invalidProblem }
            for j in 0..<i { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); guard l.metadata.variableIDs[i] != l.metadata.variableIDs[j] else { throw .invalidProblem } }
        }
        let count=try LocalKKTArithmetic.sum(m,LocalKKTArithmetic.product(2,n))
        for i in p.activeInequalities.indices {
            try LocalKKTArithmetic.charge(3,policy:policy,work:&work)
            guard p.activeInequalities[i] >= 0,p.activeInequalities[i] < count,p.initialActiveMultipliers[i].isFinite else { throw .invalidProblem }
            for j in 0..<i { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); guard p.activeInequalities[i] != p.activeInequalities[j] else { throw .invalidProblem } }
        }
        for value in p.initialEqualityMultipliers { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); guard value.isFinite else { throw .invalidProblem } }
        return (l,reserved)
    }
    private static func pattern(_ p: SparseOptimizationPattern,rows: Int,columns: Int,policy: LocalOptimizationPolicy,work: inout NumericalWork) throws(LocalOptimizationCause) {
        guard p.rows == rows,p.columns == columns,p.rowOffsets.count == (try LocalKKTArithmetic.sum(rows,1)),p.rowOffsets.first == 0,p.rowOffsets.last == p.columnIndices.count else { throw .invalidProblem }
        for i in 0..<rows {
            try LocalKKTArithmetic.charge(3,policy:policy,work:&work)
            let start=p.rowOffsets[i],end=p.rowOffsets[i+1]
            guard start >= 0,end >= start,end <= p.columnIndices.count else { throw .invalidProblem }
            var previous = -1
            for k in start..<end { try LocalKKTArithmetic.charge(3,policy:policy,work:&work); let j=p.columnIndices[k]; guard j > previous,j < columns else { throw .invalidProblem }; previous=j }
        }
    }
}

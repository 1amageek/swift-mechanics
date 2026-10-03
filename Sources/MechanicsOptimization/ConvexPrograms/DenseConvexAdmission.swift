import MechanicsCore
import MechanicsModel
import MechanicsNumerics
internal enum DenseConvexAdmission {
    static func admit(_ p: ConvexOptimizationProblem,policy: OptimizationPolicy,workspace: EnumerationWorkspace,work: inout NumericalWork) throws(OptimizationCause) -> (DenseConvexProgram,Int) {
        try OptimizationArithmetic.check(policy)
        let n=p.linearCost.count, r=p.equalities?.rowCount ?? 0, a=p.inequalities?.rowCount ?? 0
        guard n > 0, p.lowerBounds.count == n, p.upperBounds.count == n, p.equalityRightHandSide.count == r,
            p.inequalityRightHandSide.count == a, p.metadata.variableIDs.count == n, p.metadata.variableReferences.count == n,
            p.metadata.equalityReferences.count == r, p.metadata.inequalityReferences.count == a else { throw .invalidProblem }
        guard p.equalities == nil || p.equalities?.columnCount == n, p.inequalities == nil || p.inequalities?.columnCount == n,
            p.hessian == nil || (p.hessian?.rowCount == n && p.hessian?.columnCount == n), p.constantCost.isFinite else { throw .invalidProblem }
        try OptimizationArithmetic.capacity("variables",n,policy.maximumVariables)
        let m=try OptimizationArithmetic.sum(a,OptimizationArithmetic.product(2,n)), rows=try OptimizationArithmetic.sum(r,m)
        try OptimizationArithmetic.capacity("rows",rows,policy.maximumRows)
        let nnz=try OptimizationArithmetic.sum(p.equalities?.values.count ?? 0,p.inequalities?.values.count ?? 0)
        try OptimizationArithmetic.capacity("nonzeros",nnz,policy.maximumNonzeros)
        let dim=try OptimizationArithmetic.sum(n,1)
        let phaseRows=try OptimizationArithmetic.sum(OptimizationArithmetic.product(2,r),OptimizationArithmetic.sum(a,OptimizationArithmetic.product(2,dim)))
        var reserved=try OptimizationArithmetic.product(10,OptimizationArithmetic.product(dim,dim))
        reserved=try OptimizationArithmetic.sum(reserved,OptimizationArithmetic.product(4,OptimizationArithmetic.product(OptimizationArithmetic.sum(rows,phaseRows),dim)))
        reserved=try OptimizationArithmetic.sum(reserved,OptimizationArithmetic.product(40,OptimizationArithmetic.sum(dim,OptimizationArithmetic.sum(rows,phaseRows))))
        reserved=try OptimizationArithmetic.sum(reserved,workspace.retainedScalars)
        try OptimizationArithmetic.storage(reserved,work:&work)
        try metadata(p.metadata,policy:policy,work:&work)
        for i in 0..<n {
            try OptimizationArithmetic.charge(16,policy:policy,work:&work)
            guard p.linearCost[i].isFinite else { throw .invalidProblem }
            // FIXME(INCOMPLETE_IMPLEMENTATION): General unbounded affine inequality LP is outside this finite-box method.
            // Infinite-bound callers must fail until a selected recession/certificate algorithm is independently qualified.
            guard p.lowerBounds[i].isFinite, p.upperBounds[i].isFinite else { throw .unsupportedDomain }
            guard p.lowerBounds[i] <= p.upperBounds[i] else { throw .invalidProblem }
            for j in 0..<i {
                try OptimizationArithmetic.charge(1,policy:policy,work:&work)
                guard p.metadata.variableIDs[i] != p.metadata.variableIDs[j] else { throw .invalidProblem }
            }
        }
        try OptimizationArithmetic.charge(try OptimizationArithmetic.product(3,OptimizationArithmetic.sum(OptimizationArithmetic.product(r,n),OptimizationArithmetic.product(m,n))),policy:policy,work:&work)
        var equality=[Double](repeating:0,count:try OptimizationArithmetic.product(r,n))
        var inequality=[Double](repeating:0,count:try OptimizationArithmetic.product(m,n))
        var rhs=p.inequalityRightHandSide
        rhs.reserveCapacity(m)
        if let e=p.equalities { try fill(e,into:&equality,policy:policy,work:&work) }
        if let a=p.inequalities { try fill(a,into:&inequality,policy:policy,work:&work) }
        for value in p.equalityRightHandSide { guard value.isFinite else { throw .invalidProblem } }
        for value in p.inequalityRightHandSide { guard value.isFinite else { throw .invalidProblem } }
        for i in 0..<n {
            inequality[(a+2*i)*n+i] = -1; inequality[(a+2*i+1)*n+i] = 1
            rhs.append(-p.lowerBounds[i]); rhs.append(p.upperBounds[i])
        }
        var hessian: [Double]?=nil
        if let h=p.hessian {
            let entries=try OptimizationArithmetic.product(n,n)
            try OptimizationArithmetic.charge(try OptimizationArithmetic.product(2,entries),policy:policy,work:&work)
            var values=[Double](repeating:0,count:entries)
            for i in 0..<n { for j in 0..<n { do { values[i*n+j]=try h.coefficient(row:i,column:j) } catch { throw .numerical(error) } } }
            hessian=values
        }
        return (DenseConvexProgram(n:n,r:r,m:m,userInequalities:a,cost:p.linearCost,constant:p.constantCost,hessian:hessian,equality:equality,
            equalityRHS:p.equalityRightHandSide,inequality:inequality,inequalityRHS:rhs,lower:p.lowerBounds,upper:p.upperBounds),reserved)
    }
    private static func metadata(_ m: OptimizationMetadata,policy: OptimizationPolicy,work: inout NumericalWork) throws(OptimizationCause) {
        for _ in m.identity.utf8 { try OptimizationArithmetic.charge(2,policy:policy,work:&work) }
        for _ in m.provenance.source.utf8 { try OptimizationArithmetic.charge(2,policy:policy,work:&work) }
        guard m.objectiveReference.magnitude > 0 else { throw .invalidProblem }
        for q in m.variableReferences { try OptimizationArithmetic.charge(1,policy:policy,work:&work); guard q.magnitude > 0 else { throw .invalidProblem } }
        for q in m.equalityReferences { try OptimizationArithmetic.charge(1,policy:policy,work:&work); guard q.magnitude > 0 else { throw .invalidProblem } }
        for q in m.inequalityReferences { try OptimizationArithmetic.charge(1,policy:policy,work:&work); guard q.magnitude > 0 else { throw .invalidProblem } }
    }
    private static func fill(_ csr: CSRMatrix<Double>,into output: inout [Double],policy: OptimizationPolicy,work: inout NumericalWork) throws(OptimizationCause) {
        try OptimizationArithmetic.charge(try OptimizationArithmetic.product(3,csr.values.count),policy:policy,work:&work)
        for i in 0..<csr.rowCount { for k in csr.rowOffsets[i]..<csr.rowOffsets[i+1] { output[i*csr.columnCount+csr.columnIndices[k]]=csr.values[k] } }
    }
}

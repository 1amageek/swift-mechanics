internal enum ReducedLocalCurvature {
    @inline(never)
    static func prove(_ c: LocalCertificateState,nullspace z: LocalNullspace,equations q: FixedActiveKKTEquations<Double>,linear: any LinearSolving<Double>,
        policy: LocalOptimizationPolicy,context: inout LocalKKTContext,work: inout NumericalWork) throws(LocalOptimizationCause) -> [Double] {
        context.phase = .reducedCurvature
        let h: [Double]
        do {
            try KKTArithmetic.charge(q.layout.inequalityCount,work:&work,cancelled:q.cancelled)
            var user=[Double](repeating:0,count:q.layout.inequalityCount)
            for i in user.indices { user[i]=c.inequalities[i] }
            h=try KKTProgramEvaluation.hessian(q.provider,layout:q.layout,point:c.point,equalities:c.equalities,inequalities:user,scratch:q.scratch,cancelled:q.cancelled,work:&work)
        } catch { context.unavailable=KKTArithmetic.ledgerUnavailable(error); throw .callback(error) }
        let n=q.layout.variableCount,k=z.dimension,p=q.layout.lagrangianHessian
        try LocalKKTArithmetic.charge(try LocalKKTArithmetic.sum(LocalKKTArithmetic.product(n,n),LocalKKTArithmetic.product(n,k)),policy:policy,work:&work)
        var dense=[Double](repeating:0,count:try LocalKKTArithmetic.product(n,n)),image=[Double](repeating:0,count:try LocalKKTArithmetic.product(n,k))
        for i in 0..<n { for index in p.rowOffsets[i]..<p.rowOffsets[i+1] { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); dense[i*n+p.columnIndices[index]]=h[index] } }
        for i in 0..<n { for j in 0..<i { try LocalKKTArithmetic.charge(1,policy:policy,work:&work); guard dense[i*n+j] == dense[j*n+i] else { throw .numerical(.nonsymmetric) } } }
        if k == 0 { return [] }
        let entries=try LocalKKTArithmetic.product(k,k)
        try LocalKKTArithmetic.capacity(entries,policy.maximumDenseEntries)
        try LocalKKTArithmetic.charge(entries+k,policy:policy,work:&work)
        var reduced=[Double](repeating:0,count:entries)
        for i in 0..<n { for j in 0..<k { for a in 0..<n {
            try LocalKKTArithmetic.charge(2,policy:policy,work:&work); image[i*k+j]=try LocalKKTArithmetic.finite(image[i*k+j]+dense[i*n+a]*z.basis[a*k+j])
        } } }
        // One triangle is evaluated and mirrored because the admitted dense Hessian is exactly symmetric.
        for i in 0..<k { for j in 0...i {
            var value=0.0
            for a in 0..<n { try LocalKKTArithmetic.charge(2,policy:policy,work:&work); value=try LocalKKTArithmetic.finite(value+z.basis[a*k+i]*image[a*k+j]) }
            reduced[i*k+j]=value; reduced[j*k+i]=value
        } }
        let budget: NumericalBudget,result: LinearSolution<Double>
        do { budget=try work.remainingBudget(reservedStorage:context.reserved) } catch { throw .numerical(error) }
        do { result=try linear.solve(DenseMatrix(rows:k,columns:k,values:reduced),rightHandSide:[Double](repeating:0,count:k),capability:policy.curvatureCapability,tolerance:policy.curvatureTolerance,budget:budget) }
        catch { context.unavailable=true; throw .numerical(error) }
        guard result.diagnostics.work.budget == budget else { context.unavailable=true; throw .invalidSupplierLedger }
        do { try work.absorb(result.diagnostics.work,reservedStorage:context.reserved) } catch { throw .numerical(error) }
        guard result.values.count == k,result.diagnostics.capability == policy.curvatureCapability,result.diagnostics.factorization == .cholesky,result.diagnostics.numericalRank == k,
            result.diagnostics.originalResidual.isAccepted,result.values.allSatisfy({ $0.isFinite }) else { throw .invalidSupplierOutput }
        return reduced
    }
}

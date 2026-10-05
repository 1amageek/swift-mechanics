internal struct TaskSpaceLinearInvocation: Sendable {
    let solver: any LinearSolving<Double>
    @inline(never)
    func solve(_ values: [Double], rhs: [Double], system: PhysicalRigidDynamicsSystem, policy: TaskSpacePolicy,
               reserved: Int, work: inout NumericalWork) throws(TaskSpaceFailure) -> [Double] {
        try TaskSpaceArithmetic.check(system,policy)
        try TaskSpaceArithmetic.charge(1,&work)
        let capability = LinearCapability(precision:.float64,backend:.referenceCPU,algorithm:.cholesky)
        let matrix: DenseMatrix<Double>, budget: NumericalBudget
        do { matrix = try DenseMatrix(rows:rhs.count,columns:rhs.count,values:values); budget = try work.remainingBudget(reservedStorage:reserved) }
        catch { throw TaskSpaceFailure(.numerical(error)) }
        // The linear supplier creates its own ledger; failure exposes no partial consumed work.
        let result: LinearSolution<Double>
        do { result = try solver.solve(matrix,rightHandSide:rhs,capability:capability,tolerance:policy.taskLinearTolerance,budget:budget) }
        catch { throw TaskSpaceFailure(.numerical(error),failedSupplierWorkUnavailable:true) }
        let local = result.diagnostics.work
        guard local.budget == budget, local.operations <= budget.arithmeticOperations, local.iterations <= budget.iterations,
              local.peakScalarStorage <= budget.scalarStorage, local.operations >= rhs.count, local.iterations >= rhs.count else {
            throw TaskSpaceFailure(.invalidSupplierLedger,failedSupplierWorkUnavailable:true)
        }
        do { try work.absorb(local,reservedStorage:reserved) } catch { throw TaskSpaceFailure(.numerical(error)) }
        guard result.values.count == rhs.count, result.values.allSatisfy({$0.isFinite}), result.diagnostics.capability == capability,
              result.diagnostics.factorization == .cholesky, result.diagnostics.numericalRank == rhs.count else {
            throw TaskSpaceFailure(.invalidSupplierOutput)
        }
        // The unmodified supplied matrix/rhs, rather than supplier diagnostics, owns acceptance.
        var residual = 0.0, scale = 0.0
        for row in rhs.indices {
            try TaskSpaceArithmetic.check(system,policy)
            var image = 0.0
            for column in rhs.indices { try TaskSpaceArithmetic.charge(2,&work); image = try TaskSpaceArithmetic.finite(image+values[row*rhs.count+column]*result.values[column]) }
            residual = max(residual,abs(try TaskSpaceArithmetic.finite(image-rhs[row])))
            scale = max(scale,max(abs(image),abs(rhs[row])))
        }
        let threshold: Double
        do { threshold = try policy.taskLinearTolerance.threshold(scale:scale) } catch { throw TaskSpaceFailure(.numerical(error)) }
        guard residual <= threshold else { throw TaskSpaceFailure(.numerical(.residualRejected(value:residual,threshold:threshold))) }
        try TaskSpaceArithmetic.check(system,policy)
        return result.values
    }
}

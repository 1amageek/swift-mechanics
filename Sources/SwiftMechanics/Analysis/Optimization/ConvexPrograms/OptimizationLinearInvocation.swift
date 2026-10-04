internal enum OptimizationLinearInvocation {
    @inline(never)
    static func solve(_ matrix: DenseMatrix<Double>,rhs: [Double],solver: any LinearSolving<Double>,capability: LinearCapability,
        policy: OptimizationPolicy,reserved: Int,context: inout EnumerationContext,work: inout NumericalWork) throws(OptimizationCause) -> LinearSolution<Double> {
        context.phase = .linearSolve
        let budget: NumericalBudget
        do { budget=try work.remainingBudget(reservedStorage:reserved) } catch { throw .numerical(error) }
        let result: LinearSolution<Double>
        do { result=try solver.solve(matrix,rightHandSide:rhs,capability:capability,tolerance:policy.linearTolerance,budget:budget) }
        catch { context.failedSupplierWorkUnavailable=true; throw .numerical(error) }
        guard result.diagnostics.work.budget == budget else { context.failedSupplierWorkUnavailable=true; throw .invalidSupplierLedger }
        do { try work.absorb(result.diagnostics.work,reservedStorage:reserved) } catch { throw .numerical(error) }
        let factor: LinearFactorization = capability.algorithm == .cholesky ? .cholesky : .lu
        guard result.values.count == rhs.count, result.diagnostics.capability == capability,
            result.diagnostics.factorization == factor, result.diagnostics.numericalRank == rhs.count,
            result.diagnostics.originalResidual.isAccepted else { throw .invalidSupplierOutput }
        for value in result.values { guard value.isFinite else { throw .invalidSupplierOutput } }
        return result
    }
}

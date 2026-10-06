internal enum EstimatorCovarianceSolve {
    static func positiveDefinite(_ matrix: EstimatorMatrix2, policy: NonlinearEstimatorPolicy,
                                 work: inout NumericalWork) throws(NonlinearEstimatorCause) -> EstimatorMatrix2 {
        try EstimatorArithmetic.charge(64, policy: policy, work: &work)
        let symmetric = try matrix.symmetric(policy: policy)
        _ = try solve(values: symmetric.values, count: 2, rhs: [1,0], policy: policy, work: &work)
        return symmetric
    }
    static func inverseInnovation(_ variance: Double, policy: NonlinearEstimatorPolicy,
                                  work: inout NumericalWork) throws(NonlinearEstimatorCause) -> Double {
        guard variance.isFinite, variance > 0 else { throw .nonpositiveInnovation }
        return try solve(values: [variance], count: 1, rhs: [1], policy: policy, work: &work)[0]
    }
    private static func solve(values: [Double], count: Int, rhs: [Double], policy: NonlinearEstimatorPolicy,
                              work: inout NumericalWork) throws(NonlinearEstimatorCause) -> [Double] {
        try EstimatorArithmetic.charge(32, policy: policy, work: &work)
        let matrix: DenseMatrix<Double>, budget: NumericalBudget
        do { matrix = try DenseMatrix(rows: count, columns: count, values: values); budget = try work.remainingBudget(reservedStorage: 64) }
        catch { throw .numerical(error) }
        let solved: LinearSolution<Double>
        do { solved = try ReferenceLinearSolver<Double>().solve(matrix, rightHandSide: rhs,
            capability: policy.covarianceCapability, tolerance: policy.covarianceTolerance, budget: budget) }
        catch { throw .linear(error, failedSupplierWorkUnavailable: true) }
        guard solved.diagnostics.work.budget == budget else { throw .invalidSupplierOutput }
        try EstimatorArithmetic.absorb(solved.diagnostics.work, into: &work, reserved: 64)
        guard solved.values.count == count, solved.values.allSatisfy({ $0.isFinite }), solved.diagnostics.originalResidual.isAccepted,
              solved.diagnostics.capability == policy.covarianceCapability else { throw .invalidSupplierOutput }
        try EstimatorArithmetic.check(policy)
        return solved.values
    }
}

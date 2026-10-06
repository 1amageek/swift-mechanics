/// Immutable original normalized rows. Bounds are explicit signed inequalities.
internal struct LinearOriginalRows: Sendable {
    let variableCount: Int
    let equalityCount: Int
    let coefficients: [Double]
    let rightHandSide: [Double]
    let origins: [LinearRowOrigin]
    let references: [SIReferenceQuantity<Double>]
    var count: Int { rightHandSide.count }

    static func admit(_ problem: GeneralLinearProgram, policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> Self {
        let n = problem.linearCost.count, e = problem.equalities?.rowCount ?? 0, a = problem.inequalities?.rowCount ?? 0
        guard n > 0, n <= policy.maximumVariables, problem.bounds.count == n,
              problem.metadata.variableIDs.count == n, problem.metadata.variableReferences.count == n,
              problem.equalityRightHandSide.count == e, problem.inequalityRightHandSide.count == a,
              problem.metadata.equalityReferences.count == e, problem.metadata.inequalityReferences.count == a,
              problem.equalities == nil || problem.equalities?.columnCount == n,
              problem.inequalities == nil || problem.inequalities?.columnCount == n,
              problem.constantCost.isFinite, problem.metadata.objectiveReference.magnitude > 0 else { throw .invalidProblem }
        var m = try LinearProgramArithmetic.sum(e, a)
        var nnz = try LinearProgramArithmetic.sum(problem.equalities?.values.count ?? 0, problem.inequalities?.values.count ?? 0)
        for j in 0..<n {
            try LinearProgramArithmetic.charge(try LinearProgramArithmetic.sum(4, j), policy: policy, work: &work)
            guard problem.linearCost[j].isFinite, problem.metadata.variableReferences[j].magnitude > 0 else { throw .invalidProblem }
            for k in 0..<j { guard problem.metadata.variableIDs[k] != problem.metadata.variableIDs[j] else { throw .invalidProblem } }
            if let lower = problem.bounds[j].lower {
                guard lower.isFinite else { throw .invalidProblem }
                m = try LinearProgramArithmetic.sum(m, 1); nnz = try LinearProgramArithmetic.sum(nnz, 1)
            }
            if let upper = problem.bounds[j].upper {
                guard upper.isFinite else { throw .invalidProblem }
                m = try LinearProgramArithmetic.sum(m, 1); nnz = try LinearProgramArithmetic.sum(nnz, 1)
            }
        }
        guard m <= policy.maximumRows, nnz <= policy.maximumNonzeros else { throw .capacityExceeded }
        let mn = try LinearProgramArithmetic.product(m, n)
        let freeColumns = try LinearProgramArithmetic.product(2, n)
        let columns = try LinearProgramArithmetic.sum(freeColumns, try LinearProgramArithmetic.sum(m-e, m))
        let entries = try LinearProgramArithmetic.product(m, try LinearProgramArithmetic.sum(columns, 1))
        guard entries <= policy.maximumTableauEntries else { throw .capacityExceeded }
        // Conservative scalar-equivalent reservation includes original input, tableaux,
        // transforms, all simultaneously live certificate arrays and immutable metadata.
        let tableStorage = try LinearProgramArithmetic.product(8, entries)
        let transformStorage = try LinearProgramArithmetic.product(8, try LinearProgramArithmetic.product(m, m))
        let rowStorage = try LinearProgramArithmetic.product(16, mn)
        let vectors = try LinearProgramArithmetic.product(256, try LinearProgramArithmetic.sum(try LinearProgramArithmetic.sum(m, n), 1))
        let identityBytes = try LinearProgramArithmetic.metadataCount(problem.metadata.identity, policy: policy, work: &work)
        let sourceBytes = try LinearProgramArithmetic.metadataCount(problem.metadata.provenance.source, policy: policy, work: &work)
        let metadataBytes = try LinearProgramArithmetic.sum(identityBytes, sourceBytes)
        let storage = try LinearProgramArithmetic.sum(try LinearProgramArithmetic.sum(tableStorage, transformStorage),
            try LinearProgramArithmetic.sum(try LinearProgramArithmetic.sum(rowStorage, vectors), metadataBytes))
        do { try work.requireStorage(storage) } catch { throw .numerical(error) }
        try LinearProgramArithmetic.charge(try LinearProgramArithmetic.sum(mn, try LinearProgramArithmetic.product(4, m)), policy: policy, work: &work)
        var coefficients = [Double](repeating: 0, count: mn)
        var rhs = [Double](); rhs.reserveCapacity(m)
        var origins = [LinearRowOrigin](); origins.reserveCapacity(m)
        var references = [SIReferenceQuantity<Double>](); references.reserveCapacity(m)
        for r in 0..<e {
            try LinearProgramArithmetic.checkpoint(policy)
            guard problem.equalityRightHandSide[r].isFinite, problem.metadata.equalityReferences[r].magnitude > 0 else { throw .invalidProblem }
            if let matrix = problem.equalities {
                try LinearProgramArithmetic.charge(matrix.rowOffsets[r+1]-matrix.rowOffsets[r], policy: policy, work: &work)
                for k in matrix.rowOffsets[r]..<matrix.rowOffsets[r+1] { coefficients[r*n+matrix.columnIndices[k]] = matrix.values[k] }
            }
            rhs.append(problem.equalityRightHandSide[r]); origins.append(.equality(r)); references.append(problem.metadata.equalityReferences[r])
        }
        for r in 0..<a {
            try LinearProgramArithmetic.checkpoint(policy)
            guard problem.inequalityRightHandSide[r].isFinite, problem.metadata.inequalityReferences[r].magnitude > 0 else { throw .invalidProblem }
            if let matrix = problem.inequalities {
                try LinearProgramArithmetic.charge(matrix.rowOffsets[r+1]-matrix.rowOffsets[r], policy: policy, work: &work)
                for k in matrix.rowOffsets[r]..<matrix.rowOffsets[r+1] { coefficients[(e+r)*n+matrix.columnIndices[k]] = matrix.values[k] }
            }
            rhs.append(problem.inequalityRightHandSide[r]); origins.append(.inequality(r)); references.append(problem.metadata.inequalityReferences[r])
        }
        for j in 0..<n {
            try LinearProgramArithmetic.charge(2, policy: policy, work: &work)
            if let lower = problem.bounds[j].lower {
                coefficients[rhs.count*n+j] = -1; rhs.append(-lower); origins.append(.lowerBound(j)); references.append(problem.metadata.variableReferences[j])
            }
            if let upper = problem.bounds[j].upper {
                coefficients[rhs.count*n+j] = 1; rhs.append(upper); origins.append(.upperBound(j)); references.append(problem.metadata.variableReferences[j])
            }
        }
        return Self(variableCount: n, equalityCount: e, coefficients: coefficients, rightHandSide: rhs, origins: origins, references: references)
    }
}

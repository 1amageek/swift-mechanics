public struct SchurSolver<Scalar: NumericalScalar>: SchurSolving, Sendable {
    public init() {}
    public func solve(a: DenseMatrix<Scalar>, b: DenseMatrix<Scalar>, c: DenseMatrix<Scalar>, d: DenseMatrix<Scalar>,
                      primalRightHandSide f: [Scalar], reducedRightHandSide g: [Scalar], capability: LinearCapability,
                      tolerance: LinearTolerance<Scalar>, budget: NumericalBudget) throws(NumericalError) -> SchurSolution<Scalar> {
        try capability.validate(for: Scalar.self, algorithms: [.partialPivotLU])
        let n = a.rowCount, m = d.rowCount
        guard a.columnCount == n, d.columnCount == m, b.rowCount == n, b.columnCount == m,
              c.rowCount == m, c.columnCount == n, f.count == n, g.count == m else { throw .invalidDimensions }
        guard f.allSatisfy({ $0.isFinite }), g.allSatisfy({ $0.isFinite }) else { throw .nonFiniteInput }
        let nn = try NumericalWork.product(n, n), mm = try NumericalWork.product(m, m), nm = try NumericalWork.product(n, m)
        let originals = try NumericalWork.sum(try NumericalWork.sum(nn, mm), try NumericalWork.product(2, nm))
        let reserved = try NumericalWork.sum(try NumericalWork.product(3, originals), try NumericalWork.product(10, try NumericalWork.sum(n, m)))
        var work = NumericalWork(budget: budget)
        try work.requireStorage(reserved)
        let solver = ReferenceLinearSolver<Scalar>()
        let af = try solver.solve(a, rightHandSide: f, capability: capability, tolerance: tolerance,
                                  budget: work.remainingBudget(reservedStorage: reserved))
        try work.absorb(af.diagnostics.work, reservedStorage: reserved)
        var inverseB = [Scalar](repeating: 0, count: nm)
        for j in 0..<m {
            var column = [Scalar](repeating: 0, count: n)
            for i in 0..<n { column[i] = try b.coefficient(row: i, column: j) }
            let solved = try solver.solve(a, rightHandSide: column, capability: capability, tolerance: tolerance,
                                           budget: work.remainingBudget(reservedStorage: reserved))
            try work.absorb(solved.diagnostics.work, reservedStorage: reserved)
            for i in 0..<n { inverseB[i*m+j] = solved.values[i] }
        }
        var schurValues = [Scalar](repeating: 0, count: mm)
        var reducedRHS = g
        for i in 0..<m {
            for k in 0..<n {
                try work.chargeOperations(2); reducedRHS[i] -= (try c.coefficient(row: i, column: k)) * af.values[k]
            }
            guard reducedRHS[i].isFinite else { throw .nonFiniteResult }
            for j in 0..<m {
                var value = try d.coefficient(row: i, column: j)
                for k in 0..<n { try work.chargeOperations(2); value -= (try c.coefficient(row: i, column: k)) * inverseB[k*m+j] }
                guard value.isFinite else { throw .nonFiniteResult }
                schurValues[i*m+j] = value
            }
        }
        let schur = try DenseMatrix(rows: m, columns: m, values: schurValues)
        let solved = try solver.solve(schur, rightHandSide: reducedRHS, capability: capability, tolerance: tolerance,
                                       budget: work.remainingBudget(reservedStorage: reserved))
        try work.absorb(solved.diagnostics.work, reservedStorage: reserved)
        var x = af.values
        for i in 0..<n {
            for j in 0..<m { try work.chargeOperations(2); x[i] -= inverseB[i*m+j] * solved.values[j] }
            guard x[i].isFinite else { throw .nonFiniteResult }
        }
        var first = [Scalar](repeating: 0, count: n), second = [Scalar](repeating: 0, count: m)
        for i in 0..<n {
            for j in 0..<n { try work.chargeOperations(2); first[i] += (try a.coefficient(row: i, column: j)) * x[j] }
            for j in 0..<m { try work.chargeOperations(2); first[i] += (try b.coefficient(row: i, column: j)) * solved.values[j] }
        }
        for i in 0..<m {
            for j in 0..<n { try work.chargeOperations(2); second[i] += (try c.coefficient(row: i, column: j)) * x[j] }
            for j in 0..<m { try work.chargeOperations(2); second[i] += (try d.coefficient(row: i, column: j)) * solved.values[j] }
        }
        try work.chargeOperations(try NumericalWork.product(2, try NumericalWork.sum(n, m)))
        let firstEvidence = try ResidualEvidence.measure(product: first, rightHandSide: f, tolerance: tolerance)
        let secondEvidence = try ResidualEvidence.measure(product: second, rightHandSide: g, tolerance: tolerance)
        try firstEvidence.requireAccepted(); try secondEvidence.requireAccepted()
        return SchurSolution(primal: x, reduced: solved.values, schur: schur, primalResidual: firstEvidence,
                             reducedResidual: secondEvidence, work: work)
    }
}

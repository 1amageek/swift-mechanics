public struct TreeLinearSolver<Scalar: NumericalScalar>: TreeLinearSolving, Sendable {
    public init() {}
    public func solve(_ system: TreeLinearSystem<Scalar>, rightHandSide: [Scalar], capability: LinearCapability,
                      tolerance: LinearTolerance<Scalar>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Scalar> {
        try capability.validate(for: Scalar.self, algorithms: [.treeElimination])
        guard rightHandSide.count == system.count else { throw .invalidDimensions }
        guard rightHandSide.allSatisfy({ $0.isFinite }) else { throw .nonFiniteInput }
        var work = NumericalWork(budget: budget)
        try work.requireStorage(try NumericalWork.product(8, system.count))
        var diagonal = system.diagonal
        var rhs = rightHandSide
        let n = system.count
        if n > 1 {
            for i in stride(from: n-1, through: 1, by: -1) {
                try work.advanceIteration()
                guard abs(diagonal[i]) > tolerance.pivotThreshold else { throw .eliminationBreakdown(pivot: i) }
                let p = system.parents[i]
                try work.chargeOperations(5)
                let multiplier = system.edges[i] / diagonal[i]
                diagonal[p] -= multiplier * system.edges[i]
                rhs[p] -= multiplier * rhs[i]
                guard multiplier.isFinite, diagonal[p].isFinite, rhs[p].isFinite else { throw .nonFiniteResult }
            }
        }
        try work.advanceIteration()
        guard abs(diagonal[0]) > tolerance.pivotThreshold else { throw .eliminationBreakdown(pivot: 0) }
        var x = [Scalar](repeating: 0, count: n)
        try work.chargeOperations(1); x[0] = rhs[0] / diagonal[0]
        guard x[0].isFinite else { throw .nonFiniteResult }
        for i in 1..<n {
            try work.chargeOperations(3)
            x[i] = (rhs[i] - system.edges[i] * x[system.parents[i]]) / diagonal[i]
            guard x[i].isFinite else { throw .nonFiniteResult }
        }
        let image = try system.multiply(x, work: &work)
        try work.chargeOperations(try NumericalWork.product(2, n))
        let evidence = try ResidualEvidence.measure(product: image, rightHandSide: rightHandSide, tolerance: tolerance)
        try evidence.requireAccepted()
        return LinearSolution(values: x, diagnostics: LinearDiagnostics(capability: capability, factorization: .tree,
            pivoting: .none, ordering: .suppliedTree, rowPermutation: [], numericalRank: n, work: work, originalResidual: evidence))
    }
}

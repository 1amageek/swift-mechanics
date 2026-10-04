
public struct ProjectedComplementaritySolver: ComplementaritySolving, Sendable {
    public init() {}

    public func solve(_ problem: ComplementarityProblem, policy: ComplementarityPolicy, warmStart: ComplementarityCache?) throws(ComplementarityError) -> ComplementaritySolution {
        try complementarityCancelled()
        guard policy.precision == .float64, policy.backend == .referenceCPU else { throw .numerical(.unsupportedCapability) }
        let n = problem.linearTerm.count
        var work = NumericalWork(budget: policy.budget)
        let square = try product(n, n)
        // Coordinate IDs are conservatively counted as 64-bit scalar slots.
        var reserved = try sum(square, sum(product(2, n), problem.cone.coefficientCount))
        if let warmStart {
            let cachedN = warmStart.problem.linearTerm.count
            let cachedSquare = try product(warmStart.problem.matrix.rowCount, warmStart.problem.matrix.columnCount)
            let cachedStorage = try sum(cachedSquare, sum(product(2, cachedN), sum(warmStart.iterate.count, sum(warmStart.problem.cone.coefficientCount, 1))))
            reserved = try sum(reserved, cachedStorage)
        }
        try storage(sum(reserved, n), work: &work)
        if let warmStart { try validateSnapshot(warmStart, problem: problem, work: &work) }

        // Provider admission is mandatory even if the zero/warm iterate is optimal.
        let preflightBudget = try complementarityNumerical { () throws(NumericalError) in try work.remainingBudget(reservedStorage: reserved) }
        let preflightTolerance = try complementarityNumerical { () throws(NumericalError) in
            try LinearTolerance<Double>(absoluteResidual: 0, relativeResidual: 0, pivotThreshold: policy.choleskyPivotThreshold)
        }
        let admitted = try complementarityNumerical { () throws(NumericalError) in
            try ReferenceLinearSolver<Double>().solve(problem.matrix, rightHandSide: [Double](repeating: 0, count: n),
                capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
                tolerance: preflightTolerance, budget: preflightBudget)
        }
        try complementarityNumerical { () throws(NumericalError) in try work.absorb(admitted.diagnostics.work, reservedStorage: reserved) }
        let inverseBound = try rowBoundInverse(problem.matrix, work: &work)
        if let warmStart, warmStart.inverseRowBound != inverseBound { throw .invalidRestart }
        try storage(sum(reserved, product(4, n)), work: &work)
        var x = [Double](repeating: 0, count: n)
        var w = [Double](repeating: 0, count: n)
        var projectionInput = [Double](repeating: 0, count: n)
        var projected = [Double](repeating: 0, count: n)
        let projector: any ConeProjecting = ReferenceConeProjector()
        if let warmStart {
            try charge(n, work: &work)
            for i in 0..<n { x[i] = warmStart.iterate[i] }
        }
        try projector.project(x, cone: problem.cone, into: &projected, work: &work)
        swap(&x, &projected)
        var iterations = 0
        while true {
            try complementarityCancelled()
            let evidence = try residual(problem, x: x, w: &w, input: &projectionInput, projected: &projected,
                                        projector: projector, tolerance: policy.tolerance, work: &work)
            try charge(16, work: &work)
            if evidence.isAccepted {
                var objective = 0.0
                try charge(product(6, n), work: &work)
                for i in 0..<n {
                    try complementarityCancelled()
                    objective += 0.5 * x[i] * w[i] + 0.5 * x[i] * problem.linearTerm[i]
                    objective = try complementarityFinite(objective)
                }
                let cache = try ComplementarityCache(problem: problem, iterate: x, inverseRowBound: inverseBound)
                return ComplementaritySolution(values: x, dualValues: w, objective: objective, cache: cache,
                    diagnostics: ComplementarityDiagnostics(precision: policy.precision, backend: policy.backend,
                        projectedIterations: iterations, work: work, originalResidual: evidence,
                        usedWarmStart: warmStart != nil, inverseRowBound: inverseBound))
            }
            guard iterations < policy.maximumIterations else {
                throw .numerical(.nonConvergence(iterations: iterations, residual: evidence.maximumResidual))
            }
            try complementarityNumerical { () throws(NumericalError) in try work.advanceIteration() }
            iterations += 1
            try charge(product(4, n), work: &work)
            for i in 0..<n { projectionInput[i] = try complementarityFinite(x[i] - inverseBound * w[i]) }
            try projector.project(projectionInput, cone: problem.cone, into: &projected, work: &work)
            var changed = false
            try charge(n, work: &work)
            for i in 0..<n where projected[i] != x[i] { changed = true }
            guard changed else { throw .numerical(.nonConvergence(iterations: iterations, residual: evidence.maximumResidual)) }
            swap(&x, &projected)
        }
    }

    private func rowBoundInverse(_ matrix: DenseMatrix<Double>, work: inout NumericalWork) throws(ComplementarityError) -> Double {
        let n = matrix.rowCount
        try charge(sum(product(3, product(n, n)), n), work: &work)
        var bound = 0.0
        for i in 0..<n {
            try complementarityCancelled()
            var row = 0.0
            for j in 0..<n { row = try complementarityFinite(row + abs(coefficient(matrix, i, j))) }
            bound = max(bound, row)
        }
        let inverse = try complementarityFinite(1 / bound)
        guard inverse > 0 else { throw .numerical(.nonFiniteResult) }
        return inverse
    }

    private func validateSnapshot(_ cache: ComplementarityCache, problem: ComplementarityProblem, work: inout NumericalWork) throws(ComplementarityError) {
        let n = problem.linearTerm.count
        try charge(sum(product(5, n), product(n, n)), work: &work)
        guard cache.problem.identity == problem.identity, cache.problem.cone == problem.cone,
              cache.problem.linearTerm.count == n, cache.problem.matrix.rowCount == n,
              cache.problem.matrix.columnCount == n else { throw .staleCache }
        for i in 0..<n {
            try complementarityCancelled()
            guard cache.problem.linearTerm[i] == problem.linearTerm[i] else { throw .staleCache }
            for j in 0..<n {
                guard try coefficient(cache.problem.matrix, i, j) == coefficient(problem.matrix, i, j) else { throw .staleCache }
            }
        }
    }

    private func residual(_ problem: ComplementarityProblem, x: [Double], w: inout [Double], input: inout [Double],
                          projected: inout [Double], projector: any ConeProjecting, tolerance: ConeTolerance,
                          work: inout NumericalWork) throws(ComplementarityError) -> ConeResidualEvidence {
        let n = x.count
        try charge(sum(product(2, product(n, n)), product(10, n)), work: &work)
        for i in 0..<n {
            try complementarityCancelled()
            var value = problem.linearTerm[i]
            for j in 0..<n { value += try coefficient(problem.matrix, i, j) * x[j] }
            w[i] = try complementarityFinite(value)
            input[i] = try complementarityFinite(x[i] - value)
        }
        let primal = try projector.violation(x, cone: problem.cone, dual: false, work: &work)
        let dual = try projector.violation(w, cone: problem.cone, dual: true, work: &work)
        try projector.project(input, cone: problem.cone, into: &projected, work: &work)
        var optimality = 0.0
        for i in 0..<n { optimality = max(optimality, abs(try complementarityFinite(x[i] - projected[i]))) }
        var complementarity = 0.0
        try charge(product(4, n), work: &work)
        switch problem.cone {
        case .nonnegativeOrthant:
            for i in 0..<n { complementarity = max(complementarity, abs(try complementarityFinite(x[i] * w[i]))) }
        case .associatedFrictionCones(let coefficients):
            for block in coefficients.indices {
                let i = 3 * block
                let dot = try complementarityFinite(x[i] * w[i] + x[i + 1] * w[i + 1] + x[i + 2] * w[i + 2])
                complementarity = max(complementarity, abs(dot))
            }
        case .nonAssociatedCoulomb: throw .unsupportedLaw
        }
        return ConeResidualEvidence(primalFeasibility: primal, dualFeasibility: dual, complementarity: complementarity,
                                    optimality: optimality, tolerance: tolerance)
    }

    private func coefficient(_ matrix: DenseMatrix<Double>, _ row: Int, _ column: Int) throws(ComplementarityError) -> Double {
        try complementarityNumerical { () throws(NumericalError) in try matrix.coefficient(row: row, column: column) }
    }

    private func product(_ first: Int, _ second: Int) throws(ComplementarityError) -> Int {
        try complementarityNumerical { () throws(NumericalError) in try NumericalWork.product(first, second) }
    }

    private func sum(_ first: Int, _ second: Int) throws(ComplementarityError) -> Int {
        try complementarityNumerical { () throws(NumericalError) in try NumericalWork.sum(first, second) }
    }

    private func storage(_ count: Int, work: inout NumericalWork) throws(ComplementarityError) {
        try complementarityNumerical { () throws(NumericalError) in try work.requireStorage(count) }
    }

    private func charge(_ count: Int, work: inout NumericalWork) throws(ComplementarityError) {
        try complementarityNumerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
}

public struct ReferenceLinearSolver<Scalar: NumericalScalar>: LinearSolving, Sendable {
    public init() {}

    public func solve(_ matrix: DenseMatrix<Scalar>, rightHandSide: [Scalar], capability: LinearCapability,
                      tolerance: LinearTolerance<Scalar>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Scalar> {
        try capability.validate(for: Scalar.self, algorithms: [.partialPivotLU, .cholesky])
        try validate(matrix.rowCount, columns: matrix.columnCount, rhs: rightHandSide)
        let n = matrix.rowCount
        var work = NumericalWork(budget: budget)
        // Includes original storage, factor workspace, rank-diagnostic workspace and vectors.
        try work.requireStorage(try NumericalWork.sum(try NumericalWork.product(3, matrix.storage.count), try NumericalWork.product(6, n)))
        var factor = matrix.storage
        var rhs = rightHandSide
        var permutation = Array(0..<n)
        if capability.algorithm == .partialPivotLU {
            for k in 0..<n {
                try work.advanceIteration()
                var pivot = k
                for i in k..<n {
                    try work.chargeOperations(1)
                    if abs(factor[i*n+k]) > abs(factor[pivot*n+k]) { pivot = i }
                }
                guard abs(factor[pivot*n+k]) > tolerance.pivotThreshold else {
                    let rank = try numericalRank(matrix, threshold: tolerance.pivotThreshold, work: &work)
                    throw .singular(rank: rank, pivot: k)
                }
                if pivot != k {
                    for j in 0..<n { factor.swapAt(k*n+j, pivot*n+j) }
                    rhs.swapAt(k, pivot); permutation.swapAt(k, pivot)
                }
                for i in (k+1)..<n {
                    try work.chargeOperations(1)
                    let multiplier = factor[i*n+k] / factor[k*n+k]
                    guard multiplier.isFinite else { throw .nonFiniteResult }
                    factor[i*n+k] = multiplier
                    for j in (k+1)..<n {
                        try work.chargeOperations(2)
                        factor[i*n+j] -= multiplier * factor[k*n+j]
                        guard factor[i*n+j].isFinite else { throw .nonFiniteResult }
                    }
                    try work.chargeOperations(2)
                    rhs[i] -= multiplier * rhs[k]
                    guard rhs[i].isFinite else { throw .nonFiniteResult }
                }
            }
            for i in stride(from: n-1, through: 0, by: -1) {
                for j in (i+1)..<n {
                    try work.chargeOperations(2); rhs[i] -= factor[i*n+j] * rhs[j]
                }
                try work.chargeOperations(1); rhs[i] /= factor[i*n+i]
                guard rhs[i].isFinite else { throw .nonFiniteResult }
            }
        } else {
            for i in 0..<n {
                for j in 0..<i {
                    try work.chargeOperations(1)
                    guard matrix.storage[i*n+j] == matrix.storage[j*n+i] else { throw .nonsymmetric }
                }
            }
            for i in 0..<n {
                try work.advanceIteration()
                for j in 0...i {
                    var value = matrix.storage[i*n+j]
                    for k in 0..<j { try work.chargeOperations(2); value -= factor[i*n+k] * factor[j*n+k] }
                    guard value.isFinite else { throw .nonFiniteResult }
                    try work.chargeOperations(1)
                    if i == j {
                        guard value > tolerance.pivotThreshold else { throw .nonPositiveDefinite(pivot: i) }
                        factor[i*n+j] = value.squareRoot()
                    } else { factor[i*n+j] = value / factor[j*n+j] }
                    guard factor[i*n+j].isFinite else { throw .nonFiniteResult }
                }
            }
            for i in 0..<n {
                for j in 0..<i { try work.chargeOperations(2); rhs[i] -= factor[i*n+j] * rhs[j] }
                try work.chargeOperations(1); rhs[i] /= factor[i*n+i]
                guard rhs[i].isFinite else { throw .nonFiniteResult }
            }
            for i in stride(from: n-1, through: 0, by: -1) {
                for j in (i+1)..<n { try work.chargeOperations(2); rhs[i] -= factor[j*n+i] * rhs[j] }
                try work.chargeOperations(1); rhs[i] /= factor[i*n+i]
                guard rhs[i].isFinite else { throw .nonFiniteResult }
            }
        }
        let product = try matrix.multiply(rhs, work: &work)
        try work.chargeOperations(try NumericalWork.product(2, n))
        let evidence = try ResidualEvidence.measure(product: product, rightHandSide: rightHandSide, tolerance: tolerance)
        try evidence.requireAccepted()
        return LinearSolution(values: rhs, diagnostics: LinearDiagnostics(capability: capability,
            factorization: capability.algorithm == .partialPivotLU ? .lu : .cholesky,
            pivoting: capability.algorithm == .partialPivotLU ? .rowPartial : .none, ordering: .natural,
            rowPermutation: permutation, numericalRank: n, work: work, originalResidual: evidence))
    }

    public func solve(_ matrix: CSRMatrix<Scalar>, rightHandSide: [Scalar], capability: LinearCapability,
                      tolerance: LinearTolerance<Scalar>, budget: NumericalBudget) throws(NumericalError) -> LinearSolution<Scalar> {
        try capability.validate(for: Scalar.self, algorithms: [.conjugateGradient])
        try validate(matrix.rowCount, columns: matrix.columnCount, rhs: rightHandSide)
        let n = matrix.rowCount
        var work = NumericalWork(budget: budget)
        try work.requireStorage(try NumericalWork.sum(matrix.values.count, try NumericalWork.product(8, n)))
        try matrix.validateSPDProfile(work: &work)
        var x = [Scalar](repeating: 0, count: n)
        var residual = rightHandSide
        var direction = rightHandSide
        var image = [Scalar](repeating: 0, count: n)
        var rr = try dot(residual, residual, work: &work)
        let initial = try ResidualEvidence.measure(product: x, rightHandSide: rightHandSide, tolerance: tolerance)
        if initial.isAccepted { return try sparseResult(matrix, x: x, rhs: rightHandSide, capability: capability, tolerance: tolerance, work: &work) }
        while true {
            try work.advanceIteration()
            try matrix.multiply(direction, into: &image, work: &work)
            let curvature = try dot(direction, image, work: &work)
            guard curvature > tolerance.pivotThreshold else { throw .nonPositiveDefinite(pivot: work.iterations-1) }
            try work.chargeOperations(1)
            let alpha = rr / curvature
            guard alpha.isFinite else { throw .nonFiniteResult }
            var norm: Scalar = 0
            for i in 0..<n {
                try work.chargeOperations(4)
                x[i] += alpha * direction[i]; residual[i] -= alpha * image[i]
                guard x[i].isFinite, residual[i].isFinite else { throw .nonFiniteResult }
                norm = max(norm, abs(residual[i]))
            }
            var scale: Scalar = 0
            for i in 0..<n { scale = max(scale, abs(rightHandSide[i])) }
            if norm <= (try tolerance.threshold(scale: scale)) {
                return try sparseResult(matrix, x: x, rhs: rightHandSide, capability: capability, tolerance: tolerance, work: &work)
            }
            let next = try dot(residual, residual, work: &work)
            guard rr > 0 else { throw .nonConvergence(iterations: work.iterations, residual: Double(norm)) }
            try work.chargeOperations(1)
            let beta = next / rr
            guard beta.isFinite else { throw .nonFiniteResult }
            for i in 0..<n {
                try work.chargeOperations(2); direction[i] = residual[i] + beta * direction[i]
                guard direction[i].isFinite else { throw .nonFiniteResult }
            }
            rr = next
        }
    }

    private func sparseResult(_ matrix: CSRMatrix<Scalar>, x: [Scalar], rhs: [Scalar], capability: LinearCapability,
                              tolerance: LinearTolerance<Scalar>, work: inout NumericalWork) throws(NumericalError) -> LinearSolution<Scalar> {
        let image = try matrix.multiply(x, work: &work)
        try work.chargeOperations(try NumericalWork.product(2, x.count))
        let evidence = try ResidualEvidence.measure(product: image, rightHandSide: rhs, tolerance: tolerance)
        try evidence.requireAccepted()
        return LinearSolution(values: x, diagnostics: LinearDiagnostics(capability: capability, factorization: .none,
            pivoting: .none, ordering: .natural, rowPermutation: [], numericalRank: nil, work: work, originalResidual: evidence))
    }

    private func validate(_ rows: Int, columns: Int, rhs: [Scalar]) throws(NumericalError) {
        guard rows == columns, rhs.count == rows else { throw .invalidDimensions }
        guard rhs.allSatisfy({ $0.isFinite }) else { throw .nonFiniteInput }
        guard !Task.isCancelled else { throw .cancelled }
    }

    private func dot(_ first: [Scalar], _ second: [Scalar], work: inout NumericalWork) throws(NumericalError) -> Scalar {
        try work.chargeOperations(try NumericalWork.product(2, first.count))
        var value: Scalar = 0
        for i in first.indices { value += first[i] * second[i] }
        guard value.isFinite else { throw .nonFiniteResult }
        return value
    }

    private func numericalRank(_ matrix: DenseMatrix<Scalar>, threshold: Scalar, work: inout NumericalWork) throws(NumericalError) -> Int {
        var values = matrix.storage
        let n = matrix.rowCount
        var rank = 0
        for column in 0..<n {
            guard !Task.isCancelled else { throw .cancelled }
            var pivot = rank
            for i in rank..<n {
                try work.chargeOperations(1)
                if abs(values[i*n+column]) > abs(values[pivot*n+column]) { pivot = i }
            }
            if abs(values[pivot*n+column]) <= threshold { continue }
            if pivot != rank { for j in 0..<n { values.swapAt(rank*n+j, pivot*n+j) } }
            for i in (rank+1)..<n {
                try work.chargeOperations(1)
                let multiplier = values[i*n+column] / values[rank*n+column]
                guard multiplier.isFinite else { throw .nonFiniteResult }
                for j in column..<n {
                    try work.chargeOperations(2); values[i*n+j] -= multiplier * values[rank*n+j]
                    guard values[i*n+j].isFinite else { throw .nonFiniteResult }
                }
            }
            rank += 1
            if rank == n { break }
        }
        return rank
    }
}

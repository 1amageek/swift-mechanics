internal enum LinearEstimatorAlgebra {
    static func check(_ policy: LinearEstimatorPolicy) throws(LinearEstimatorError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }
    static func charge(_ count: Int, policy: LinearEstimatorPolicy, work: inout NumericalWork) throws(LinearEstimatorError) {
        try check(policy)
        do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func product(_ a: Int, _ b: Int) throws(LinearEstimatorError) -> Int {
        do { return try NumericalWork.product(a, b) } catch { throw .numerical(error) }
    }
    static func sum(_ a: Int, _ b: Int) throws(LinearEstimatorError) -> Int {
        do { return try NumericalWork.sum(a, b) } catch { throw .numerical(error) }
    }
    static func storage(_ count: Int, work: inout NumericalWork) throws(LinearEstimatorError) {
        do { try work.requireStorage(count) } catch { throw .numerical(error) }
    }
    static func metadata(_ text: String, policy: LinearEstimatorPolicy, work: inout NumericalWork) throws(LinearEstimatorError) {
        guard !text.isEmpty else { throw .invalidModel }
        var count = 0
        for _ in text.utf8 {
            guard count < policy.maximumMetadataBytes else { throw .capacity }
            try charge(1, policy: policy, work: &work); count += 1
        }
    }
    static func coordinates(_ values: [LinearEstimatorCoordinate], policy: LinearEstimatorPolicy,
                            work: inout NumericalWork) throws(LinearEstimatorError) {
        for i in values.indices {
            let coordinate = values[i]
            try metadata(coordinate.identity, policy: policy, work: &work)
            try metadata(coordinate.frame, policy: policy, work: &work)
            guard coordinate.normalizationSI.isFinite, coordinate.normalizationSI > 0 else { throw .invalidModel }
            for j in 0..<i {
                try charge(try sum(coordinate.identity.utf8.count, values[j].identity.utf8.count), policy: policy, work: &work)
                guard coordinate.identity != values[j].identity else { throw .invalidModel }
            }
        }
    }
    static func policy(_ p: LinearEstimatorPolicy) throws(LinearEstimatorError) {
        try check(p)
        guard p.maximumStateCount > 0, p.maximumInputCount > 0, p.maximumObservationCount > 0,
              p.maximumMetadataBytes > 0, p.maximumContinuationBytes > 0,
              p.maximumCoefficientMagnitude.isFinite, p.maximumCoefficientMagnitude > 0,
              p.covarianceTolerance.isFinite, p.covarianceTolerance >= 0,
              p.rankThreshold.isFinite, p.rankThreshold > 0 else { throw .invalidPolicy }
    }
    static func reserve(_ model: LinearEstimatorModel, policy: LinearEstimatorPolicy,
                        work: inout NumericalWork) throws(LinearEstimatorError) -> Int {
        try self.policy(policy)
        let n = model.stateCoordinates.count, r = model.inputCoordinates.count, m = model.observationCoordinates.count
        guard n > 0, n <= policy.maximumStateCount, r > 0, r <= policy.maximumInputCount,
              m > 0, m <= policy.maximumObservationCount else { throw .capacity }
        let nn = try product(n, n), mm = try product(m, m), nm = try product(n, m), nr = try product(n, r)
        // Includes inputs, retained prefix, all temporary matrices, observability workspace and output COW copies.
        let slots = try product(40, try sum(try sum(nn, mm), try sum(try sum(nm, nr), try sum(try product(nn, m), try sum(n, try sum(m, r))))))
        try storage(slots, work: &work)
        try metadata(model.source.identity, policy: policy, work: &work)
        try metadata(model.filterIdentity, policy: policy, work: &work)
        try metadata(model.chartIdentity, policy: policy, work: &work)
        try coordinates(model.stateCoordinates, policy: policy, work: &work)
        try coordinates(model.inputCoordinates, policy: policy, work: &work)
        try coordinates(model.observationCoordinates, policy: policy, work: &work)
        for matrix in [model.transition, model.input, model.observation, model.processCovariance, model.observationCovariance] {
            for value in matrix.storage {
                try charge(1, policy: policy, work: &work)
                guard abs(value) <= policy.maximumCoefficientMagnitude else { throw .invalidModel }
            }
        }
        return slots
    }
    static func matrix(_ values: [Double], rows: Int, columns: Int) throws(LinearEstimatorError) -> DenseMatrix<Double> {
        do { return try DenseMatrix(rows: rows, columns: columns, values: values) } catch { throw .numerical(error) }
    }
    static func finite(_ value: Double) throws(LinearEstimatorError) -> Double {
        guard value.isFinite else { throw .numerical(.nonFiniteResult) }; return value
    }
    static func multiply(_ a: DenseMatrix<Double>, _ b: DenseMatrix<Double>, policy: LinearEstimatorPolicy,
                         work: inout NumericalWork) throws(LinearEstimatorError) -> DenseMatrix<Double> {
        guard a.columnCount == b.rowCount else { throw .invalidModel }
        var values = [Double](repeating: 0, count: try product(a.rowCount, b.columnCount))
        for i in 0..<a.rowCount {
            for j in 0..<b.columnCount {
                var value = 0.0
                for k in 0..<a.columnCount {
                    try charge(2, policy: policy, work: &work)
                    value = try finite(value + a.storage[i*a.columnCount+k]*b.storage[k*b.columnCount+j])
                }
                values[i*b.columnCount+j] = value
            }
        }
        return try matrix(values, rows: a.rowCount, columns: b.columnCount)
    }
    static func transpose(_ a: DenseMatrix<Double>, policy: LinearEstimatorPolicy,
                          work: inout NumericalWork) throws(LinearEstimatorError) -> DenseMatrix<Double> {
        var values = [Double](repeating: 0, count: a.storage.count)
        for i in 0..<a.rowCount { for j in 0..<a.columnCount {
            try charge(1, policy: policy, work: &work); values[j*a.rowCount+i] = a.storage[i*a.columnCount+j]
        } }
        return try matrix(values, rows: a.columnCount, columns: a.rowCount)
    }
    static func add(_ a: DenseMatrix<Double>, _ b: DenseMatrix<Double>, policy: LinearEstimatorPolicy,
                    work: inout NumericalWork) throws(LinearEstimatorError) -> DenseMatrix<Double> {
        guard a.rowCount == b.rowCount, a.columnCount == b.columnCount else { throw .invalidModel }
        var values = a.storage
        for i in values.indices { try charge(1, policy: policy, work: &work); values[i] = try finite(values[i]+b.storage[i]) }
        return try matrix(values, rows: a.rowCount, columns: a.columnCount)
    }
    static func symmetric(_ matrix: DenseMatrix<Double>, allowRoundoff: Bool, policy: LinearEstimatorPolicy,
                          work: inout NumericalWork) throws(LinearEstimatorError) -> DenseMatrix<Double> {
        guard matrix.rowCount == matrix.columnCount else { throw .invalidCovariance(pivot: 0) }
        var values = matrix.storage
        let n = matrix.rowCount
        for i in 0..<n { for j in 0..<i {
            try charge(4, policy: policy, work: &work)
            let a = values[i*n+j], b = values[j*n+i]
            guard allowRoundoff ? abs(a-b) <= policy.covarianceTolerance : a == b else { throw .invalidCovariance(pivot: i) }
            if allowRoundoff { let mean = try finite(a/2+b/2); values[i*n+j] = mean; values[j*n+i] = mean }
        } }
        return try self.matrix(values, rows: n, columns: n)
    }
    static func covariance(_ matrix: DenseMatrix<Double>, positive: Bool, policy: LinearEstimatorPolicy,
                           work: inout NumericalWork) throws(LinearEstimatorError) {
        _ = try symmetric(matrix, allowRoundoff: false, policy: policy, work: &work)
        let n = matrix.rowCount
        var factor = matrix.storage
        // Symmetric Schur elimination admits zero PSD pivots only when the remaining pivot column is zero within tolerance.
        for k in 0..<n {
            try charge(1, policy: policy, work: &work)
            let pivot = factor[k*n+k]
            if positive {
                guard pivot > policy.solveTolerance.pivotThreshold else { throw .invalidCovariance(pivot: k) }
            } else {
                guard pivot >= -policy.covarianceTolerance else { throw .invalidCovariance(pivot: k) }
                if abs(pivot) <= policy.covarianceTolerance {
                    for i in (k+1)..<n {
                        try charge(1, policy: policy, work: &work)
                        guard abs(factor[i*n+k]) <= policy.covarianceTolerance else { throw .invalidCovariance(pivot: k) }
                    }
                    continue
                }
            }
            for i in (k+1)..<n { for j in i..<n {
                try charge(4, policy: policy, work: &work)
                let value = try finite(factor[j*n+i] - factor[i*n+k]/pivot*factor[j*n+k])
                factor[j*n+i] = value; factor[i*n+j] = value
            } }
        }
    }
    static func observable(_ model: LinearEstimatorModel, policy: LinearEstimatorPolicy,
                           work: inout NumericalWork) throws(LinearEstimatorError) {
        let n = model.transition.rowCount, m = model.observation.rowCount, rows = try product(n, m)
        var values = [Double](repeating: 0, count: try product(rows, n)), power = model.observation
        for k in 0..<n {
            for i in power.storage.indices { try charge(1, policy: policy, work: &work); values[k*m*n+i] = power.storage[i] }
            if k+1 < n { power = try multiply(power, model.transition, policy: policy, work: &work) }
        }
        var rank = 0
        for column in 0..<n {
            var pivot = rank
            for i in rank..<rows { try charge(1, policy: policy, work: &work); if abs(values[i*n+column]) > abs(values[pivot*n+column]) { pivot = i } }
            if abs(values[pivot*n+column]) <= policy.rankThreshold { continue }
            if rank != pivot { for j in 0..<n { try charge(1, policy: policy, work: &work); values.swapAt(rank*n+j, pivot*n+j) } }
            for i in (rank+1)..<rows {
                try charge(1, policy: policy, work: &work)
                let ratio = try finite(values[i*n+column]/values[rank*n+column])
                for j in column..<n { try charge(2, policy: policy, work: &work); values[i*n+j] = try finite(values[i*n+j]-ratio*values[rank*n+j]) }
            }
            rank += 1
            if rank == n { return }
        }
        throw .unobservable(rank: rank)
    }
    static func solve(_ matrix: DenseMatrix<Double>, rhs: [Double], reserved: Int, policy: LinearEstimatorPolicy,
                      work: inout NumericalWork) throws(LinearEstimatorError) -> LinearSolution<Double> {
        let n = matrix.rowCount, nn = try product(n, n)
        let operations = try sum(try product(8, try product(nn, n)), try sum(try product(16, nn), try product(16, n)))
        let slots = try sum(try product(3, nn), try product(6, n))
        try storage(try sum(reserved, slots), work: &work)
        try charge(operations, policy: policy, work: &work)
        // Reservation is deliberately not refunded: supplier failure has no actual-work payload.
        for _ in 0..<n {
            try check(policy)
            do { try work.advanceIteration() } catch { throw .numerical(error) }
        }
        let budget: NumericalBudget
        do { budget = try NumericalBudget(scalarStorage: slots, arithmeticOperations: operations, iterations: n) }
        catch { throw .numerical(error) }
        let result: LinearSolution<Double>
        do {
            result = try ReferenceLinearSolver<Double>().solve(matrix, rightHandSide: rhs,
                capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
                tolerance: policy.solveTolerance, budget: budget)
        } catch { throw .failedSupplierWorkUnavailable(error) }
        try check(policy)
        return result
    }
    static func time(_ clock: LinearEstimatorClock, tick: UInt64) throws(LinearEstimatorError) -> Double {
        // Exact integer-to-Double conversion prevents adjacent ticks from aliasing above binary64's exact integer range.
        guard tick <= clock.maximumTick, let scalar = Double(exactly: tick) else { throw .timingMismatch }
        return try finite(clock.epochSeconds + scalar*clock.periodSeconds)
    }
}

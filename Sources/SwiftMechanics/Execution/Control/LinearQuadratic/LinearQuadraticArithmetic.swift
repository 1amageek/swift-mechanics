internal enum LinearQuadraticArithmetic {
    static func numeric<T>(_ body: () throws(NumericalError) -> T) throws(LinearQuadraticFailure) -> T {
        do { return try body() } catch { throw LinearQuadraticFailure(.numerical(error), phase: "numerics") }
    }
    static func check(_ policy: LinearQuadraticPolicy, work: NumericalWork) throws(LinearQuadraticFailure) {
        guard work.budget == policy.budget else { throw LinearQuadraticFailure(.invalidInput, phase: "budget") }
        guard !policy.isCancelled(), !Task.isCancelled else { throw LinearQuadraticFailure(.cancelled, phase: "cancellation") }
    }
    static func charge(_ count: Int, policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) {
        try check(policy, work: work)
        try numeric { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func size(_ a: Int, _ b: Int) throws(LinearQuadraticFailure) -> Int {
        try numeric { () throws(NumericalError) in try NumericalWork.product(a, b) }
    }
    static func reserve(states n: Int, inputs m: Int, policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) -> Int {
        try check(policy, work: work)
        guard n > 0, n <= policy.maximumStates, m > 0, m <= policy.maximumInputs else {
            throw LinearQuadraticFailure(.capacity, phase: "shape")
        }
        let nn = try size(n, n), nm = try size(n, m), mm = try size(m, m), fourth = try size(nn, nn)
        let reserve = try numeric { () throws(NumericalError) in
            try NumericalWork.sum(try NumericalWork.product(32, nn), try NumericalWork.sum(
                try NumericalWork.product(16, nm), try NumericalWork.sum(try NumericalWork.product(16, mm), try NumericalWork.product(2, fourth))))
        }
        try numeric { () throws(NumericalError) in try work.requireStorage(reserve) }
        return reserve
    }
    static func retainingSource(_ source: EquilibriumLinearization, reserve: Int,
                                policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) -> Int {
        let n = source.operatingPoint.model.chart.count
        let rows = source.operatingPoint.constraints?.system.rows.count ?? 0
        let outputs = source.reduction.outputRows
        guard n <= policy.maximumStates, rows <= policy.maximumStates, outputs > 0, outputs <= policy.maximumStates else {
            throw LinearQuadraticFailure(.capacity, phase: "retained-linearization")
        }
        // Includes the original point, force law, chart, rows, reduction and derivative matrices.
        let extra = try numeric { () throws(NumericalError) in
            try NumericalWork.sum(try NumericalWork.product(64, try NumericalWork.product(n, n)),
                try NumericalWork.sum(try NumericalWork.product(16, try NumericalWork.product(rows, n)),
                    try NumericalWork.product(8, try NumericalWork.product(outputs, n))))
        }
        let combined = try numeric { () throws(NumericalError) in try NumericalWork.sum(reserve, extra) }
        try numeric { () throws(NumericalError) in try work.requireStorage(combined) }
        return combined
    }
    static func metadata(_ text: String, policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) {
        var count = 0
        for _ in text.utf8 {
            try charge(1, policy: policy, work: &work)
            guard count < policy.maximumMetadataBytes else { throw LinearQuadraticFailure(.capacity, phase: "metadata") }
            count += 1
        }
        guard count > 0 else { throw LinearQuadraticFailure(.invalidInput, phase: "identity") }
    }
    static func finite(_ values: [Double], policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) {
        try charge(values.count, policy: policy, work: &work)
        guard values.allSatisfy({ $0.isFinite }) else { throw LinearQuadraticFailure(.invalidInput, phase: "finite") }
    }
    static func multiply(_ a: [Double], _ b: [Double], rows: Int, inner: Int, columns: Int,
                         into result: inout [Double], policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) {
        let count = try size(rows, columns)
        try charge(try size(2, try size(count, inner)), policy: policy, work: &work)
        for i in 0..<rows { for j in 0..<columns {
            var value = 0.0
            for k in 0..<inner { value += a[i*inner+k]*b[k*columns+j] }
            guard value.isFinite else { throw LinearQuadraticFailure(.numerical(.nonFiniteResult), phase: "product") }
            result[i*columns+j] = value
        } }
    }
    static func transpose(_ a: [Double], rows: Int, columns: Int, into result: inout [Double],
                          policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) {
        try charge(a.count, policy: policy, work: &work)
        for i in 0..<rows { for j in 0..<columns { result[j*rows+i] = a[i*columns+j] } }
    }
    static func symmetric(_ a: [Double], dimension n: Int, exact: Bool, policy: LinearQuadraticPolicy,
                          work: inout NumericalWork) throws(LinearQuadraticFailure) -> (values: [Double], error: Double) {
        var values = a
        let error = try symmetrize(&values, dimension: n, exact: exact, policy: policy, work: &work)
        return (values, error)
    }
    static func symmetrize(_ values: inout [Double], dimension n: Int, exact: Bool, policy: LinearQuadraticPolicy,
                           work: inout NumericalWork) throws(LinearQuadraticFailure) -> Double {
        try finite(values, policy: policy, work: &work)
        try charge(try size(5, values.count), policy: policy, work: &work)
        var error = 0.0
        for i in 0..<n { for j in 0..<i {
            let difference = abs(values[i*n+j]-values[j*n+i]); error = max(error, difference)
            guard exact ? difference == 0 : difference <= policy.symmetryTolerance else {
                throw LinearQuadraticFailure(.nonsymmetricCost, phase: "symmetry")
            }
            let mean = values[i*n+j] == values[j*n+i] ? values[i*n+j] : values[i*n+j]*0.5+values[j*n+i]*0.5
            values[i*n+j] = mean; values[j*n+i] = mean
        } }
        return error
    }
    /// Symmetric pivoted Schur complements validate PSD, including null-pivot rows.
    static func positivity(_ a: [Double], dimension n: Int, strict: Bool, allowRoundoff: Bool = false,
                           policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) {
        if !strict && !allowRoundoff {
            for i in 0..<n { for j in 0..<i {
                try charge(128, policy: policy, work: &work)
                guard LinearQuadraticCostMinor.accepts(a[i*n+i], a[j*n+j], coupling: a[i*n+j]) else {
                    throw LinearQuadraticFailure(.indefiniteStateCost, phase: "PSD-principal-minor")
                }
            } }
        }
        var factor = a
        for k in 0..<n {
            try charge(try size(4, try size(n, n)), policy: policy, work: &work)
            var pivot = k
            for i in k..<n { if factor[i*n+i] > factor[pivot*n+pivot] { pivot = i } }
            if pivot != k {
                for j in 0..<n { factor.swapAt(k*n+j, pivot*n+j) }
                for i in 0..<n { factor.swapAt(i*n+k, i*n+pivot) }
            }
            let diagonal = factor[k*n+k]
            if strict {
                guard diagonal > policy.tolerance.pivotThreshold else {
                    throw LinearQuadraticFailure(.numerical(.nonPositiveDefinite(pivot: k)), phase: "positive-definite")
                }
            } else {
                let threshold = allowRoundoff ? policy.semidefiniteTolerance : 0
                guard diagonal >= -threshold else { throw LinearQuadraticFailure(.indefiniteStateCost, phase: "PSD") }
                if diagonal <= threshold {
                    for i in k..<n { for j in k..<n {
                        guard abs(factor[i*n+j]) <= threshold else {
                            throw LinearQuadraticFailure(.indefiniteStateCost, phase: "PSD-nullspace")
                        }
                    } }
                    return
                }
            }
            for i in (k+1)..<n { for j in i..<n {
                let value = factor[i*n+j]-factor[i*n+k]*(factor[j*n+k]/diagonal)
                guard value.isFinite else { throw LinearQuadraticFailure(.numerical(.nonFiniteResult), phase: "PSD") }
                factor[i*n+j] = value; factor[j*n+i] = value
            } }
        }
    }
    static func solve(_ a: [Double], dimension n: Int, rhs: [Double], algorithm: LinearAlgorithm,
                      linear: any LinearSolving<Double>, reserve: Int, policy: LinearQuadraticPolicy,
                      work: inout NumericalWork) throws(LinearQuadraticFailure) -> [Double] {
        try check(policy, work: work)
        let matrix = try numeric { () throws(NumericalError) in try DenseMatrix<Double>(rows: n, columns: n, values: a) }
        let remaining = try numeric { () throws(NumericalError) in try work.remainingBudget(reservedStorage: reserve) }
        let capability = LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: algorithm)
        let solution: LinearSolution<Double>
        do { solution = try linear.solve(matrix, rightHandSide: rhs, capability: capability, tolerance: policy.tolerance, budget: remaining) }
        catch { throw LinearQuadraticFailure(.numerical(error), phase: "linear-supplier", failedSupplierWorkUnavailable: true) }
        guard solution.diagnostics.work.budget == remaining, solution.diagnostics.capability == capability,
              solution.diagnostics.factorization == (algorithm == .cholesky ? .cholesky : .lu),
              solution.diagnostics.numericalRank == n else {
            throw LinearQuadraticFailure(.invalidSupplierLedger, phase: "linear-supplier", failedSupplierWorkUnavailable: true)
        }
        try numeric { () throws(NumericalError) in try work.absorb(solution.diagnostics.work, reservedStorage: reserve) }
        guard solution.values.count == n, solution.values.allSatisfy({ $0.isFinite }) else {
            throw LinearQuadraticFailure(.invalidSupplierOutput, phase: "linear-supplier")
        }
        var product = [Double](repeating: 0, count: n)
        try multiply(a, solution.values, rows: n, inner: n, columns: 1, into: &product, policy: policy, work: &work)
        _ = try residual(product, rhs, policy: policy, work: &work)
        return solution.values
    }
    static func residual(_ a: [Double], _ b: [Double], policy: LinearQuadraticPolicy,
                         work: inout NumericalWork) throws(LinearQuadraticFailure) -> Double {
        try charge(try size(4, a.count), policy: policy, work: &work)
        var value = 0.0, scale = 0.0
        for i in a.indices {
            guard a[i].isFinite, b[i].isFinite else { throw LinearQuadraticFailure(.numerical(.nonFiniteResult), phase: "original-residual") }
            value = max(value, abs(a[i]-b[i])); scale = max(scale, max(abs(a[i]), abs(b[i])))
        }
        let threshold = try numeric { () throws(NumericalError) in try policy.tolerance.threshold(scale: scale) }
        guard value <= threshold else { throw LinearQuadraticFailure(.originalEvidenceRejected, phase: "original-residual") }
        return value
    }
}

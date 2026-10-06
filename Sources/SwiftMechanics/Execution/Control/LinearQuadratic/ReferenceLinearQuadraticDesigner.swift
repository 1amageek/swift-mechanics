public struct ReferenceLinearQuadraticDesigner: LinearQuadraticDesigning, Sendable {
    public let linear: any LinearSolving<Double>
    public init(linear: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) { self.linear = linear }
    public func design(_ system: DiscreteControlSystem, stateCost: [Double], inputCost: [Double], stabilizingGainWitness: [Double],
                       policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) -> LinearQuadraticDesign {
        do throws(LinearQuadraticFailure) {
            let n = system.stateCount, m = system.inputCount
            var reserve = try LinearQuadraticArithmetic.reserve(states: n, inputs: m, policy: policy, work: &work)
            if case .equilibriumBilinear(let source, _) = system.provenance {
                reserve = try LinearQuadraticArithmetic.retainingSource(source, reserve: reserve, policy: policy, work: &work)
            }
            let nn = try LinearQuadraticArithmetic.size(n, n), nm = try LinearQuadraticArithmetic.size(n, m), mm = try LinearQuadraticArithmetic.size(m, m)
            guard stateCost.count == nn, inputCost.count == mm, stabilizingGainWitness.count == nm else {
                throw LinearQuadraticFailure(.invalidInput, phase: "cost-shape")
            }
            try LinearQuadraticArithmetic.metadata(system.identity, policy: policy, work: &work)
            let q = try LinearQuadraticArithmetic.symmetric(stateCost, dimension: n, exact: true, policy: policy, work: &work).values
            let r = try LinearQuadraticArithmetic.symmetric(inputCost, dimension: m, exact: true, policy: policy, work: &work).values
            try LinearQuadraticArithmetic.positivity(q, dimension: n, strict: false, policy: policy, work: &work)
            try positiveDefinite(r, dimension: m, reserve: reserve, policy: policy, work: &work)
            try LinearQuadraticArithmetic.finite(stabilizingGainWitness, policy: policy, work: &work)
            let witness: (matrix: [Double], residual: Double)
            do { witness = try stability(system, gain: stabilizingGainWitness, reserve: reserve, policy: policy, work: &work) }
            catch {
                // A rejected numerical witness is not a mathematical proof of unstabilizability.
                switch error.cause {
                case .originalEvidenceRejected, .nonsymmetricCost, .indefiniteStateCost,
                     .numerical(.singular), .numerical(.nonPositiveDefinite), .numerical(.residualRejected):
                    throw LinearQuadraticFailure(.stabilizabilityWitnessRejected, phase: "stabilizing-witness",
                        failedSupplierWorkUnavailable: error.failedSupplierWorkUnavailable)
                default: throw error
                }
            }
            var scratch = LinearQuadraticWorkspace(statesSquared: nn, stateInputs: nm, inputsSquared: mm, inputs: m)
            try LinearQuadraticArithmetic.transpose(system.stateMatrix, rows: n, columns: n, into: &scratch.at, policy: policy, work: &work)
            try LinearQuadraticArithmetic.transpose(system.inputMatrix, rows: n, columns: m, into: &scratch.bt, policy: policy, work: &work)
            var p = q, lastResidual = Double.infinity, maximumAsymmetry = 0.0
            for iteration in 1...policy.maximumRiccatiIterations {
                try LinearQuadraticArithmetic.numeric { () throws(NumericalError) in try work.advanceIteration() }
                try step(system, p: p, q: q, r: r, scratch: &scratch, reserve: reserve, policy: policy, work: &work)
                var scale = 0.0; lastResidual = 0
                try LinearQuadraticArithmetic.charge(try LinearQuadraticArithmetic.size(4, nn), policy: policy, work: &work)
                for i in 0..<nn { lastResidual = max(lastResidual, abs(scratch.next[i]-p[i])); scale = max(scale, max(abs(scratch.next[i]), abs(p[i]))) }
                let asymmetry = try LinearQuadraticArithmetic.symmetrize(&scratch.next, dimension: n, exact: false, policy: policy, work: &work)
                maximumAsymmetry = max(maximumAsymmetry, asymmetry)
                swap(&p, &scratch.next)
                let threshold = try LinearQuadraticArithmetic.numeric { () throws(NumericalError) in try policy.tolerance.threshold(scale: scale) }
                if lastResidual <= threshold {
                    // Recompute at the returned P; an iteration-difference flag is not acceptance.
                    try step(system, p: p, q: q, r: r, scratch: &scratch, reserve: reserve, policy: policy, work: &work)
                    let originalResidual = try LinearQuadraticArithmetic.residual(p, scratch.next, policy: policy, work: &work)
                    try LinearQuadraticArithmetic.positivity(p, dimension: n, strict: false, allowRoundoff: true, policy: policy, work: &work)
                    var originalDenominator = scratch.bpb
                    try LinearQuadraticArithmetic.charge(mm, policy: policy, work: &work)
                    for i in 0..<mm { originalDenominator[i] += r[i] }
                    var gainProduct = [Double](repeating: 0, count: nm)
                    try LinearQuadraticArithmetic.multiply(originalDenominator, scratch.gain, rows: m, inner: m, columns: n,
                        into: &gainProduct, policy: policy, work: &work)
                    let gainResidual = try LinearQuadraticArithmetic.residual(gainProduct, scratch.bpa, policy: policy, work: &work)
                    let certificate = try stability(system, gain: scratch.gain, reserve: reserve, policy: policy, work: &work)
                    try LinearQuadraticArithmetic.check(policy, work: work)
                    return LinearQuadraticDesign(system: system, stateCost: q, inputCost: r, riccatiMatrix: p, feedbackGain: scratch.gain,
                        diagnostics: LinearQuadraticDiagnostics(riccatiIterations: iteration, originalRiccatiResidual: originalResidual,
                            originalGainResidual: gainResidual, maximumRiccatiAsymmetry: maximumAsymmetry,
                            witnessLyapunovResidual: witness.residual, closedLoopLyapunovResidual: certificate.residual,
                            closedLoopLyapunovMatrix: certificate.matrix, work: work))
                }
            }
            throw LinearQuadraticFailure(.nonconvergence(iterations: policy.maximumRiccatiIterations, residual: lastResidual), phase: "Riccati")
        } catch { throw error.retaining(work) }
    }
    private func positiveDefinite(_ matrix: [Double], dimension: Int, reserve: Int,
                                  policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) {
        try LinearQuadraticArithmetic.positivity(matrix, dimension: dimension, strict: true, policy: policy, work: &work)
        _ = try LinearQuadraticArithmetic.solve(matrix, dimension: dimension, rhs: [Double](repeating: 0, count: dimension), algorithm: .cholesky,
            linear: linear, reserve: reserve, policy: policy, work: &work)
    }
    private func step(_ system: DiscreteControlSystem, p: [Double], q: [Double], r: [Double], scratch s: inout LinearQuadraticWorkspace,
                      reserve: Int, policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) {
        let n = system.stateCount, m = system.inputCount
        try LinearQuadraticArithmetic.multiply(p, system.stateMatrix, rows: n, inner: n, columns: n, into: &s.pa, policy: policy, work: &work)
        try LinearQuadraticArithmetic.multiply(p, system.inputMatrix, rows: n, inner: n, columns: m, into: &s.pb, policy: policy, work: &work)
        try LinearQuadraticArithmetic.multiply(s.at, s.pa, rows: n, inner: n, columns: n, into: &s.apa, policy: policy, work: &work)
        try LinearQuadraticArithmetic.multiply(s.bt, s.pb, rows: m, inner: n, columns: m, into: &s.bpb, policy: policy, work: &work)
        try LinearQuadraticArithmetic.multiply(s.bt, s.pa, rows: m, inner: n, columns: n, into: &s.bpa, policy: policy, work: &work)
        try LinearQuadraticArithmetic.charge(r.count, policy: policy, work: &work)
        for i in r.indices { s.denominator[i] = r[i]+s.bpb[i] }
        _ = try LinearQuadraticArithmetic.symmetrize(&s.denominator, dimension: m, exact: false, policy: policy, work: &work)
        try LinearQuadraticArithmetic.positivity(s.denominator, dimension: m, strict: true, policy: policy, work: &work)
        for j in 0..<n {
            for i in 0..<m { s.rhs[i] = s.bpa[i*n+j] }
            let column = try LinearQuadraticArithmetic.solve(s.denominator, dimension: m, rhs: s.rhs, algorithm: .cholesky,
                linear: linear, reserve: reserve, policy: policy, work: &work)
            for i in 0..<m { s.gain[i*n+j] = column[i] }
        }
        try LinearQuadraticArithmetic.transpose(s.bpa, rows: m, columns: n, into: &s.bpat, policy: policy, work: &work)
        try LinearQuadraticArithmetic.multiply(s.bpat, s.gain, rows: n, inner: m, columns: n, into: &s.correction, policy: policy, work: &work)
        try LinearQuadraticArithmetic.charge(try LinearQuadraticArithmetic.size(2, q.count), policy: policy, work: &work)
        for i in q.indices {
            s.next[i] = q[i]+s.apa[i]-s.correction[i]
            guard s.next[i].isFinite else { throw LinearQuadraticFailure(.numerical(.nonFiniteResult), phase: "Riccati") }
        }
    }
    private func stability(_ system: DiscreteControlSystem, gain: [Double], reserve: Int, policy: LinearQuadraticPolicy,
                           work: inout NumericalWork) throws(LinearQuadraticFailure) -> (matrix: [Double], residual: Double) {
        let n = system.stateCount, m = system.inputCount, nn = system.stateMatrix.count
        var f = [Double](repeating: 0, count: nn)
        try LinearQuadraticArithmetic.multiply(system.inputMatrix, gain, rows: n, inner: m, columns: n, into: &f, policy: policy, work: &work)
        try LinearQuadraticArithmetic.charge(nn, policy: policy, work: &work)
        for i in 0..<nn { f[i] = system.stateMatrix[i]-f[i] }
        let fourth = try LinearQuadraticArithmetic.size(nn, nn)
        try LinearQuadraticArithmetic.charge(try LinearQuadraticArithmetic.size(3, fourth), policy: policy, work: &work)
        var equation = [Double](repeating: 0, count: fourth), identity = [Double](repeating: 0, count: nn)
        for i in 0..<n { for j in 0..<n {
            let row = i*n+j; identity[row] = i == j ? 1 : 0
            for a in 0..<n { for b in 0..<n {
                equation[row*nn+a*n+b] = (i == a && j == b ? 1 : 0)-f[a*n+i]*f[b*n+j]
            } }
        } }
        let raw = try LinearQuadraticArithmetic.solve(equation, dimension: nn, rhs: identity, algorithm: .partialPivotLU,
            linear: linear, reserve: reserve, policy: policy, work: &work)
        let w = try LinearQuadraticArithmetic.symmetric(raw, dimension: n, exact: false, policy: policy, work: &work).values
        try positiveDefinite(w, dimension: n, reserve: reserve, policy: policy, work: &work)
        var wf = [Double](repeating: 0, count: nn), ft = wf, image = wf
        try LinearQuadraticArithmetic.multiply(w, f, rows: n, inner: n, columns: n, into: &wf, policy: policy, work: &work)
        try LinearQuadraticArithmetic.transpose(f, rows: n, columns: n, into: &ft, policy: policy, work: &work)
        try LinearQuadraticArithmetic.multiply(ft, wf, rows: n, inner: n, columns: n, into: &image, policy: policy, work: &work)
        try LinearQuadraticArithmetic.charge(nn, policy: policy, work: &work)
        for i in 0..<nn { image[i] = w[i]-image[i] }
        let residual = try LinearQuadraticArithmetic.residual(image, identity, policy: policy, work: &work)
        let decrement = try LinearQuadraticArithmetic.symmetric(image, dimension: n, exact: false, policy: policy, work: &work).values
        try positiveDefinite(decrement, dimension: n, reserve: reserve, policy: policy, work: &work)
        return (w, residual)
    }
}

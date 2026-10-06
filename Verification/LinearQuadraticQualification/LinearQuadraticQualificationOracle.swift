import SwiftMechanics

public enum LinearQuadraticQualificationOracle {
    public static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw LinearQuadraticQualificationError.assertion(message) }
    }
    public static func close(_ value: Double, _ expected: Double, _ message: String, physical: Bool = false) throws {
        let tolerance = physical ? 1e-9 : 1e-8
        try require(value.isFinite && expected.isFinite && abs(value-expected) <= tolerance+tolerance*max(abs(value), abs(expected)), message)
    }
    public static func array(_ value: [Double], _ expected: [Double], _ message: String, physical: Bool = false) throws {
        try require(value.count == expected.count, message + " shape")
        for i in value.indices { try close(value[i], expected[i], message + " slot \(i)", physical: physical) }
    }
    public static func scalar(a: Double, b: Double, q: Double, r: Double) -> (p: Double, k: Double, f: Double, w: Double) {
        let c = r*(1-a*a)-q*b*b
        let p = (-c+(c*c+4*b*b*q*r).squareRoot())/(2*b*b)
        let k = b*p*a/(r+b*b*p), f = a-b*k
        return (p, k, f, 1/(1-f*f))
    }
    /// Reconstruct original DARE/gain/Lyapunov equations using plain scalar loops.
    public static func equations(_ design: LinearQuadraticDesign) throws {
        let n = design.system.stateCount, m = design.system.inputCount
        let a = design.system.stateMatrix, b = design.system.inputMatrix, p = design.riccatiMatrix, k = design.feedbackGain
        let q = design.stateCost, r = design.inputCost, w = design.diagnostics.closedLoopLyapunovMatrix
        var f = a
        for i in 0..<n { for j in 0..<n { for t in 0..<m { f[i*n+j] -= b[i*m+t]*k[t*n+j] } } }
        for i in 0..<m { for j in 0..<n {
            var denominatorGain = 0.0, right = 0.0
            for t in 0..<m {
                var denominator = r[i*m+t]
                for u in 0..<n { for v in 0..<n { denominator += b[u*m+i]*p[u*n+v]*b[v*m+t] } }
                denominatorGain += denominator*k[t*n+j]
            }
            for u in 0..<n { for v in 0..<n { right += b[u*m+i]*p[u*n+v]*a[v*n+j] } }
            try close(denominatorGain, right, "Original gain equation")
        } }
        for i in 0..<n { for j in 0..<n {
            var next = q[i*n+j], decrement = w[i*n+j]
            for u in 0..<n { for v in 0..<n {
                next += f[u*n+i]*p[u*n+v]*f[v*n+j]
                decrement -= f[u*n+i]*w[u*n+v]*f[v*n+j]
            } }
            for u in 0..<m { for v in 0..<m { next += k[u*n+i]*r[u*m+v]*k[v*n+j] } }
            try close(p[i*n+j], next, "Original closed-loop DARE")
            try close(decrement, i == j ? 1 : 0, "Original Lyapunov equation")
            try close(p[i*n+j], p[j*n+i], "P symmetry")
            try close(w[i*n+j], w[j*n+i], "W symmetry")
        } }
        try require(w[0] > 0 && (n == 1 || w[0]*w[3]-w[1]*w[2] > 0), "Independent positive W")
        if n == 1 { try require(abs(f[0]) < 1, "Independent scalar Schur pole") }
        else {
            let trace = f[0]+f[3], determinant = f[0]*f[3]-f[1]*f[2]
            let discriminant = trace*trace-4*determinant
            if discriminant >= 0 {
                try require(abs((trace+discriminant.squareRoot())/2) < 1 && abs((trace-discriminant.squareRoot())/2) < 1,
                    "Independent real Schur poles")
            } else { try require(determinant > 0 && determinant.squareRoot() < 1, "Independent complex Schur pole magnitudes") }
        }
        var x = [Double](repeating: 0.3, count: n), stageCost = 0.0
        let initial = quadratic(p, x)
        for _ in 0..<40 {
            var u = [Double](repeating: 0, count: m), next = [Double](repeating: 0, count: n)
            for i in 0..<m { for j in 0..<n { u[i] -= k[i*n+j]*x[j] } }
            stageCost += quadratic(q, x)+quadratic(r, u)
            for i in 0..<n { for j in 0..<n { next[i] += a[i*n+j]*x[j] }; for j in 0..<m { next[i] += b[i*m+j]*u[j] } }
            x = next
        }
        try close(stageCost+quadratic(p, x), initial, "Finite cost plus terminal value")
    }
    private static func quadratic(_ matrix: [Double], _ x: [Double]) -> Double {
        var value = 0.0
        for i in x.indices { for j in x.indices { value += x[i]*matrix[i*x.count+j]*x[j] } }
        return value
    }
}

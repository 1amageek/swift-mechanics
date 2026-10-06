// Local second-order analytic chain rule, at most nine translation coordinates.
// Storage belongs to the element call; no finite differences or shared derivative cache.
internal struct CableJet {
    let value: Double
    let gradient: [Double]
    let hessian: [Double]

    init(_ value: Double, count: Int, coordinate: Int? = nil) {
        self.value = value
        var gradient = [Double](repeating: 0, count: count)
        if let coordinate { gradient[coordinate] = 1 }
        self.gradient = gradient
        hessian = [Double](repeating: 0, count: count * count)
    }
    private init(value: Double, gradient: [Double], hessian: [Double]) {
        self.value = value; self.gradient = gradient; self.hessian = hessian
    }
    func adding(_ other: CableJet) -> CableJet {
        var g = gradient, h = hessian
        for i in g.indices { g[i] += other.gradient[i] }
        for i in h.indices { h[i] += other.hessian[i] }
        return CableJet(value: value + other.value, gradient: g, hessian: h)
    }
    func scaled(_ scale: Double) -> CableJet {
        var g = gradient, h = hessian
        for i in g.indices { g[i] *= scale }
        for i in h.indices { h[i] *= scale }
        return CableJet(value: value * scale, gradient: g, hessian: h)
    }
    func divided(by divisor: Double) -> CableJet {
        var g = gradient, h = hessian
        for i in g.indices { g[i] /= divisor }
        for i in h.indices { h[i] /= divisor }
        return CableJet(value: value / divisor, gradient: g, hessian: h)
    }
    func subtracting(_ other: CableJet) -> CableJet { adding(other.scaled(-1)) }
    func multiplied(_ other: CableJet) -> CableJet {
        let n = gradient.count
        var g = gradient, h = hessian
        for i in 0..<n {
            g[i] = gradient[i] * other.value + value * other.gradient[i]
            for j in 0..<n {
                h[i*n+j] = hessian[i*n+j] * other.value + value * other.hessian[i*n+j]
                    + gradient[i] * other.gradient[j] + other.gradient[i] * gradient[j]
            }
        }
        return CableJet(value: value * other.value, gradient: g, hessian: h)
    }
    private func composed(value output: Double, first: Double, second: Double) -> CableJet {
        let n = gradient.count
        var g = gradient, h = hessian
        for i in 0..<n {
            g[i] = first * gradient[i]
            for j in 0..<n { h[i*n+j] = first * hessian[i*n+j] + second * gradient[i] * gradient[j] }
        }
        return CableJet(value: output, gradient: g, hessian: h)
    }
    func squareRoot() throws(CableError) -> CableJet {
        guard value.isFinite, value > 0 else { throw .nonFiniteResult }
        let root = value.squareRoot(), first = 0.5 / root
        return composed(value: root, first: first, second: -first / (2 * value))
    }
    func reciprocal() throws(CableError) -> CableJet {
        guard value.isFinite, value > 0 else { throw .nonFiniteResult }
        let inverse = 1 / value
        return composed(value: inverse, first: -inverse * inverse, second: 2 * inverse * inverse * inverse)
    }
    func validate(includeHessian: Bool) throws(CableError) {
        guard value.isFinite else { throw .nonFiniteResult }
        for scalar in gradient { guard scalar.isFinite else { throw .nonFiniteResult } }
        if includeHessian { for scalar in hessian { guard scalar.isFinite else { throw .nonFiniteResult } } }
    }
}

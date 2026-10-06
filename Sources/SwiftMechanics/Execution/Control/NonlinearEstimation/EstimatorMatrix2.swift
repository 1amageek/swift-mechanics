internal struct EstimatorMatrix2: Sendable {
    let a: Double, b: Double, c: Double, d: Double
    var values: [Double] { [a,b,c,d] }
    static let identity = Self(a: 1,b: 0,c: 0,d: 1)
    init(a: Double, b: Double, c: Double, d: Double) { self.a=a;self.b=b;self.c=c;self.d=d }
    init(_ values: [Double]) throws(NonlinearEstimatorCause) {
        guard values.count == 4, values.allSatisfy({ $0.isFinite }) else { throw .invalidCovariance }
        self.init(a:values[0],b:values[1],c:values[2],d:values[3])
    }
    func checked() throws(NonlinearEstimatorCause) -> Self {
        guard a.isFinite, b.isFinite, c.isFinite, d.isFinite else { throw .invalidCovariance }; return self
    }
    var transposed: Self { Self(a:a,b:c,c:b,d:d) }
    func adding(_ x: Self) throws(NonlinearEstimatorCause) -> Self { try Self(a:a+x.a,b:b+x.b,c:c+x.c,d:d+x.d).checked() }
    func scaled(_ x: Double) throws(NonlinearEstimatorCause) -> Self { try Self(a:a*x,b:b*x,c:c*x,d:d*x).checked() }
    func multiplying(_ x: Self) throws(NonlinearEstimatorCause) -> Self {
        try Self(a:a*x.a+b*x.c,b:a*x.b+b*x.d,c:c*x.a+d*x.c,d:c*x.b+d*x.d).checked()
    }
    func symmetric(policy: NonlinearEstimatorPolicy) throws(NonlinearEstimatorCause) -> Self {
        guard max(max(abs(a),abs(b)),max(abs(c),abs(d))) <= policy.maximumNormalizedCovarianceMagnitude else {
            throw .covarianceMagnitudeExceeded
        }
        guard try EstimatorArithmetic.agreement(b, c, policy.covarianceSymmetry) else { throw .invalidCovariance }
        let off = b == c ? b : b/2+c/2, magnitude = max(max(abs(a),abs(off)),abs(d))
        guard magnitude <= policy.maximumNormalizedCovarianceMagnitude else { throw .covarianceMagnitudeExceeded }
        return try Self(a:a,b:off,c:off,d:d).checked()
    }
    func positiveSemidefinite() throws(NonlinearEstimatorCause) {
        guard a >= 0, d >= 0, b == c else { throw .invalidCovariance }
        // A nonzero coupling with a zero diagonal is indefinite even when b*b underflows.
        if a == 0 || d == 0 {
            guard b == 0 else { throw .invalidCovariance }
            return
        }
        if b == 0 { return }
        let diagonal = Self.exactProduct(a, d), coupling = Self.exactProduct(b, b)
        let accepted = diagonal.exponent != coupling.exponent
            ? diagonal.exponent > coupling.exponent
            : diagonal.high != coupling.high
                ? diagonal.high > coupling.high : diagonal.low >= coupling.low
        guard accepted else { throw .invalidCovariance }
    }

    // Inputs are nonzero finite binary64 magnitudes admitted by the matrix constructor.
    // Each significand has at most 53 bits; its full product has at most 106 bits.
    // Exponent sums stay within -2148...1942. Normalization shifts only within 0...127.
    // Integer words preserve every product bit, including subnormal boundary products.
    private static func exactProduct(_ x: Double, _ y: Double) -> (exponent: Int, high: UInt64, low: UInt64) {
        let left = binaryParts(x), right = binaryParts(y)
        let product = left.significand.multipliedFullWidth(by: right.significand)
        let count = product.high == 0 ? 64-product.low.leadingZeroBitCount : 128-product.high.leadingZeroBitCount
        let shift = 128-count
        let high: UInt64, low: UInt64
        if shift >= 64 {
            high = product.low << (shift-64); low = 0
        } else {
            high = (product.high << shift) | (product.low >> (64-shift))
            low = product.low << shift
        }
        return (left.exponent+right.exponent+count, high, low)
    }

    private static func binaryParts(_ value: Double) -> (significand: UInt64, exponent: Int) {
        let bits = value.bitPattern, fraction = bits & 0x000f_ffff_ffff_ffff
        let exponent = Int((bits >> 52) & 0x7ff)
        return exponent == 0 ? (fraction, -1074) : (fraction | (UInt64(1) << 52), exponent-1075)
    }
}

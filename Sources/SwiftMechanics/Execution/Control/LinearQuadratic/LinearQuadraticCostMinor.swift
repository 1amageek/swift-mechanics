/// Exact necessary principal-minor admission for an already finite symmetric caller cost.
internal enum LinearQuadraticCostMinor {
    static func accepts(_ a: Double, _ d: Double, coupling b: Double) -> Bool {
        guard a >= 0, d >= 0 else { return false }
        if a == 0 || d == 0 { return b == 0 }
        if b == 0 { return true }
        let diagonal = exactProduct(a, d), coupling = exactProduct(b, b)
        return diagonal.exponent != coupling.exponent
            ? diagonal.exponent > coupling.exponent
            : diagonal.high != coupling.high
                ? diagonal.high > coupling.high : diagonal.low >= coupling.low
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

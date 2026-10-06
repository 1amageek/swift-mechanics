/// Outward arithmetic for original triangle rejection certificates; no interval is a successful hit.
internal struct HeightfieldInterval: Sendable {
    let lower: Double
    let upper: Double

    static let zero = HeightfieldInterval(point:0)

    init(point: Double) { lower = point; upper = point }

    init(lower: Double, upper: Double) throws(HeightfieldError) {
        guard lower.isFinite, upper.isFinite, lower <= upper else { throw .arithmeticFailure }
        self.lower = lower; self.upper = upper
    }

    var isZero: Bool { lower == 0 && upper == 0 }
    var excludesZero: Bool { lower > 0 || upper < 0 }

    func adding(_ other: Self) throws(HeightfieldError) -> Self {
        if isZero { return other }; if other.isZero { return self }
        return try Self(lower:(lower+other.lower).nextDown,upper:(upper+other.upper).nextUp)
    }

    func subtracting(_ other: Self) throws(HeightfieldError) -> Self {
        if other.isZero { return self }
        if lower == upper, other.lower == other.upper, lower == other.lower { return .zero }
        return try Self(lower:(lower-other.upper).nextDown,upper:(upper-other.lower).nextUp)
    }

    func negated() throws(HeightfieldError) -> Self { try Self(lower:-upper,upper:-lower) }

    func multiplied(by other: Self) throws(HeightfieldError) -> Self {
        if isZero || other.isZero { return .zero }
        let a = try HeightfieldMath.finite(lower*other.lower), b = try HeightfieldMath.finite(lower*other.upper)
        let c = try HeightfieldMath.finite(upper*other.lower), d = try HeightfieldMath.finite(upper*other.upper)
        return try Self(lower:min(min(a,b),min(c,d)).nextDown,upper:max(max(a,b),max(c,d)).nextUp)
    }

    func divided(by other: Self) throws(HeightfieldError) -> Self {
        guard other.excludesZero else { throw .ambiguousRay }
        if isZero { return .zero }
        let a = try HeightfieldMath.finite(lower/other.lower), b = try HeightfieldMath.finite(lower/other.upper)
        let c = try HeightfieldMath.finite(upper/other.lower), d = try HeightfieldMath.finite(upper/other.upper)
        return try Self(lower:min(min(a,b),min(c,d)).nextDown,upper:max(max(a,b),max(c,d)).nextUp)
    }
}

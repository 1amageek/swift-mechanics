/// Signed physical interval; bounds retain the coordinate's declared SI units.
public struct RetimingInterval: Equatable, Sendable {
    public let lower: Double
    public let upper: Double
    public init(lower: Double, upper: Double) throws(RetimingError) {
        guard lower.isFinite, upper.isFinite, lower <= upper else { throw .invalidInput }
        self.lower = lower; self.upper = upper
    }
    public func contains(_ value: Double) -> Bool { value.isFinite && value >= lower && value <= upper }
    internal init(uncheckedLower: Double, upper: Double) { lower = uncheckedLower; self.upper = upper }
}

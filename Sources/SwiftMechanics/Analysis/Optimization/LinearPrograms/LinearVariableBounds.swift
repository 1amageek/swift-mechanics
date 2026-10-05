public struct LinearVariableBounds: Equatable, Sendable {
    public let lower: Double?
    public let upper: Double?
    public static let unrestricted = LinearVariableBounds(uncheckedLower: nil, upper: nil)
    public init(lower: Double?, upper: Double?) throws(LinearProgramCause) {
        if let lower { guard lower.isFinite else { throw .invalidProblem } }
        if let upper { guard upper.isFinite else { throw .invalidProblem } }
        self.lower = lower; self.upper = upper
    }
    private init(uncheckedLower: Double?, upper: Double?) { lower = uncheckedLower; self.upper = upper }
}

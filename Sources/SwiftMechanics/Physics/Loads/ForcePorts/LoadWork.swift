public struct LoadWork: Sendable {
    public let budget: LoadBudget
    public private(set) var consumed: Int = 0
    public private(set) var peakScalars: Int = 0
    public init(budget: LoadBudget) { self.budget = budget }
    public mutating func charge(_ units: Int) throws(LoadError) {
        guard !budget.isCancelled() else { throw .cancelled }
        guard units >= 0 else { throw .invalidInput }
        let (next, overflow) = consumed.addingReportingOverflow(units)
        guard !overflow, next <= budget.maximumWork else { throw .workExhausted }
        consumed = next
    }
    public mutating func reserve(scalars: Int) throws(LoadError) {
        try charge(0)
        guard scalars >= 0, scalars <= budget.maximumScalars else { throw .capacityExceeded }
        peakScalars = max(peakScalars, scalars)
    }
    public static func product(_ a: Int, _ b: Int) throws(LoadError) -> Int {
        guard a >= 0, b >= 0 else { throw .invalidInput }
        let (count, overflow) = a.multipliedReportingOverflow(by: b)
        guard !overflow else { throw .capacityExceeded }
        return count
    }
    public static func sum(_ a: Int, _ b: Int) throws(LoadError) -> Int {
        guard a >= 0, b >= 0 else { throw .invalidInput }
        let (count, overflow) = a.addingReportingOverflow(b)
        guard !overflow else { throw .capacityExceeded }
        return count
    }
}

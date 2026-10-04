public struct CoordinateRange: Equatable, Sendable {
    public let start: Int
    public let count: Int
    public let end: Int
    public var range: Range<Int> { start..<end }

    public init(start: Int, count: Int) throws(JointError) {
        guard start >= 0, count >= 0 else { throw .invalidCoordinateCount }
        let (end, overflow) = start.addingReportingOverflow(count)
        guard !overflow else { throw .integerOverflow }
        self.start = start; self.count = count; self.end = end
    }
}

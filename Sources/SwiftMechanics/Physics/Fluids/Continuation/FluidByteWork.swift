public struct FluidByteWork: Equatable, Sendable {
    public let maximumBytes: Int
    public let maximumVisitedBytes: Int
    public private(set) var visitedBytes: Int = 0
    public private(set) var peakBytes: Int = 0
    public init(maximumBytes: Int, maximumVisitedBytes: Int) throws(FluidError) {
        guard maximumBytes >= 0, maximumVisitedBytes >= 0 else { throw .invalidInput }
        self.maximumBytes=maximumBytes; self.maximumVisitedBytes=maximumVisitedBytes
    }
    public mutating func reserve(_ count: Int) throws(FluidError) {
        guard count >= 0, count <= maximumBytes else { throw .capacity }; peakBytes=max(peakBytes,count)
    }
    public mutating func visit(_ count: Int) throws(FluidError) {
        let (next,overflow)=visitedBytes.addingReportingOverflow(count)
        guard count >= 0, !overflow, next <= maximumVisitedBytes else { throw .capacity }; visitedBytes=next
    }
}

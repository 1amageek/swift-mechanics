public struct CADAdapterWork: Sendable {
    public let maximumVisits: Int
    public private(set) var visits: Int = 0
    private let isCancelled: @Sendable () -> Bool

    public init(maximumVisits: Int, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(CADAdapterError) {
        guard maximumVisits >= 0 else { throw .invalidInput }
        self.maximumVisits = maximumVisits
        self.isCancelled = isCancelled
    }

    mutating func charge(_ count: Int = 1) throws(CADAdapterError) {
        try poll()
        guard count >= 0 else { throw .invalidInput }
        let next = visits.addingReportingOverflow(count)
        guard !next.overflow, next.partialValue <= maximumVisits else { throw .capacityExceeded }
        visits = next.partialValue
    }

    func poll() throws(CADAdapterError) {
        guard !isCancelled(), !Task.isCancelled else { throw .cancelled }
    }
}

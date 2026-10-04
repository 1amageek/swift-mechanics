public struct PlanarContinuationWork: Sendable {
    public let maximumStorageBytes: Int
    public let maximumWorkUnits: Int
    public let isCancelled: @Sendable () -> Bool
    public private(set) var workUnits = 0
    public private(set) var peakStorageBytes = 0
    public init(maximumStorageBytes: Int, maximumWorkUnits: Int,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(PlanarContinuationError) {
        guard maximumStorageBytes >= 0, maximumWorkUnits >= 0 else { throw .invalidInput }
        self.maximumStorageBytes = maximumStorageBytes; self.maximumWorkUnits = maximumWorkUnits
        self.isCancelled = isCancelled
    }
    public func poll() throws(PlanarContinuationError) {
        guard !Task.isCancelled, !isCancelled() else { throw .cancelled }
    }
    public mutating func reserve(_ count: Int) throws(PlanarContinuationError) {
        try poll()
        guard count >= 0, count <= maximumStorageBytes else { throw .capacity }
        peakStorageBytes = max(peakStorageBytes, count)
    }
    public mutating func charge(_ units: Int) throws(PlanarContinuationError) {
        try poll()
        let (next, overflow) = workUnits.addingReportingOverflow(units)
        guard units >= 0, !overflow, next <= maximumWorkUnits else { throw .capacity }
        workUnits = next
    }
    internal mutating func metadata(_ text: String, remaining: inout Int) throws(PlanarContinuationError) {
        guard !text.isEmpty else { throw .invalidInput }
        // Covers iterator admission and the later bounded two-input byte comparisons.
        var iterator = text.utf8.makeIterator()
        while true {
            try charge(3)
            guard iterator.next() != nil else { break }
            guard remaining > 0 else { throw .capacity }; remaining -= 1
        }
    }
}

import Synchronization

@available(macOS 15.0, *)
final class SpatialProjectionQualificationCounter: Sendable {
    private let count = Mutex(0)
    private let threshold: Int
    init(threshold: Int) { self.threshold = threshold }
    func cancelled() -> Bool {
        count.withLock { value in value += 1; return value >= threshold }
    }
    var calls: Int { count.withLock { $0 } }
}

import Synchronization

internal final class FieldOutputsCancellationCounter: Sendable {
    private let state = Mutex(0)
    private let cancelAt: Int?
    init(cancelAt: Int? = nil) { self.cancelAt=cancelAt }
    func check() -> Bool {
        state.withLock { count in
            count += 1
            if let cancelAt { return count >= cancelAt }
            return false
        }
    }
    var count: Int { state.withLock { $0 } }
}

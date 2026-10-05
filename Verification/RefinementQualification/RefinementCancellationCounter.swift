import Synchronization

internal final class RefinementCancellationCounter: Sendable {
    private let state = Mutex(0)
    private let cancelAt: Int?
    init(cancelAt: Int? = nil) { self.cancelAt=cancelAt }
    func check() -> Bool {
        state.withLock { count in count+=1;return cancelAt == count }
    }
    var count: Int { state.withLock { $0 } }
}

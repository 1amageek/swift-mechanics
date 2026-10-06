import Synchronization

@available(macOS 15.0, *)
internal final class ShellsCancellationCounter: Sendable {
    private let value = Mutex<Int>(0)
    let limit: Int
    init(limit: Int = Int.max) { self.limit = limit }
    func checkpoint() -> Bool { value.withLock { count in count += 1; return count >= limit } }
    var count: Int { value.withLock { $0 } }
}

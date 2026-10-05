import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class FrictionalImpulseCancellationCounter: Sendable {
    private let state = Mutex(0)
    private let cancelAt: Int?
    init(cancelAt: Int? = nil) { self.cancelAt = cancelAt }
    func check() -> Bool { state.withLock { count in count += 1; return count == cancelAt } }
    var count: Int { state.withLock { $0 } }
}

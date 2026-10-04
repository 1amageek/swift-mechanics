import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class HybridCancellation: Sendable {
    private let storage = Mutex(false)
    public init() {}
    public func cancel() { storage.withLock { $0 = true } }
    public var isCancelled: Bool { storage.withLock { $0 } }
    public func check() throws(HybridError) {
        guard !isCancelled, !Task.isCancelled else { throw .cancelled }
    }
}

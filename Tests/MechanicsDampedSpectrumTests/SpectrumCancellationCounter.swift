import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class SpectrumCancellationCounter: Sendable {
    private let calls=Mutex(0)
    private let limit:Int
    init(limit:Int) { self.limit=limit }
    func cancelled() -> Bool { calls.withLock { value in if value<limit { value+=1 };return value>=limit } }
}

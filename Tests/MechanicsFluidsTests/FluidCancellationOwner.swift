import Synchronization
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
final class FluidCancellationOwner: Sendable {
    private let cancelled=Mutex(false)
    func cancel() { cancelled.withLock { $0=true } }
    func read() -> Bool { cancelled.withLock { $0 } }
}

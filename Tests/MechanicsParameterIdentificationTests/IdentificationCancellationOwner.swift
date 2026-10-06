import Synchronization

@available(macOS 15,iOS 18,tvOS 18,watchOS 11,*)
final class IdentificationCancellationOwner: Sendable {
    private let state=Mutex(false)
    var isCancelled:Bool { state.withLock { $0 } }
    func cancel() { state.withLock { $0=true } }
}

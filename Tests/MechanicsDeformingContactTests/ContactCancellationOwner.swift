import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
final class ContactCancellationOwner: Sendable {
    private let value=Mutex(false)
    func cancel() { value.withLock { $0=true } }
    func cancelled() -> Bool { value.withLock { $0 } }
}

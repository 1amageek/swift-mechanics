import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
final class ControlCancellationOwner: Sendable {
    private let flag=Mutex(false)
    func cancel() { flag.withLock { $0=true } }
    func read() -> Bool { flag.withLock { $0 } }
}

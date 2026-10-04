import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class NonlinearMechanismCapture: Sendable {
    private let state=Mutex(NonlinearMechanismAttempt())
    func store(_ value:NonlinearMechanismAttempt) { state.withLock { $0=value } }
    func read() -> NonlinearMechanismAttempt { state.withLock { $0 } }
}

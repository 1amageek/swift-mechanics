import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class StructuralAttemptCapture: Sendable {
    private let state = Mutex(StructuralAttemptState())
    func read() -> StructuralAttemptState { state.withLock { $0 } }
    func fail(_ cause: ImplicitMethodCause, unavailable: Bool = false) {
        state.withLock { if case nil = $0.cause { $0.cause = cause }; $0.unavailable = $0.unavailable || unavailable }
    }
}

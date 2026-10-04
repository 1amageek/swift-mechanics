import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IntegrationAttemptCapture: Sendable {
    private let state = Mutex(IntegrationAttemptEvidence())
    func store(_ value: IntegrationAttemptEvidence) { state.withLock { $0 = value } }
    func read() -> IntegrationAttemptEvidence { state.withLock { $0 } }
}

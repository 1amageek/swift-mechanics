import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class ImplicitAttemptCapture: Sendable {
    private let state: Mutex<ImplicitAttemptState>
    init(budget: NumericalBudget) { state = Mutex(ImplicitAttemptState(work: NumericalWork(budget: budget))) }
    func read() -> ImplicitAttemptState { state.withLock { $0 } }
    func update(_ operation: (inout sending ImplicitAttemptState) -> sending Void) { state.withLock(operation) }
}

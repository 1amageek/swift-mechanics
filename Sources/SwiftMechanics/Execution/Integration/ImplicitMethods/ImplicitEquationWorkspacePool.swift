import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class ImplicitEquationWorkspacePool: Sendable {
    private let state: Mutex<ImplicitEquationWorkspace?>
    init(count: Int, entries: Int) { state = Mutex(ImplicitEquationWorkspace(count: count, entries: entries)) }
    func take() throws(NonlinearCause) -> ImplicitEquationWorkspace {
        let value = state.withLock { stored -> ImplicitEquationWorkspace? in
            let value = stored; stored = nil; return value
        }
        guard let value else { throw .invalidEvaluation }
        return value
    }
    func put(_ value: ImplicitEquationWorkspace) { state.withLock { $0 = value } }
}

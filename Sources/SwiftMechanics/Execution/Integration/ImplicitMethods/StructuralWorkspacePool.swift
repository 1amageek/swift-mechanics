import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class StructuralWorkspacePool: Sendable {
    private let state: Mutex<StructuralEvaluationWorkspace?>
    init(count: Int, entries: Int) { state = Mutex(StructuralEvaluationWorkspace(count: count, entries: entries)) }
    func take() throws(NonlinearCause) -> StructuralEvaluationWorkspace {
        let value = state.withLock { stored -> StructuralEvaluationWorkspace? in
            let value = stored; stored = nil; return value
        }
        guard let value else { throw .invalidEvaluation }
        return value
    }
    func put(_ value: StructuralEvaluationWorkspace) { state.withLock { $0 = value } }
}

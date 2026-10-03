import Synchronization
import MechanicsCompiler
import MechanicsRuntime

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class RuntimeProbeLifecycle: Sendable {
    typealias Session = RuntimeSession<ReferenceRuntimeCheckpointHandler<ProbeRuntimeContributors, ReferenceModelRevisionUpdater>>
    private let retained = Mutex<Session?>(nil)
    private let releases = Mutex(0)
    func retain(_ session: Session) { retained.withLock { $0 = session } }
    var releaseCount: Int { releases.withLock { $0 } }
    func release() {
        let owner = retained.withLock { value -> Session? in let previous = value; value = nil; return previous }
        if let owner { _ = owner.snapshot(); _ = owner.shutdown() }
        releases.withLock { $0 += 1 }
    }
}

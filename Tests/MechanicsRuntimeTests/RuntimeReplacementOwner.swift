import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class RuntimeReplacementOwner: Sendable {
    private struct State: Sendable {
        weak var session: RuntimeSession<RuntimeReplacementHandler>?
        var retired = 0
        var snapshot: RuntimeAcceptedState?
    }
    private let storage = Mutex(State())
    func bind(_ session: RuntimeSession<RuntimeReplacementHandler>) { storage.withLock { $0.session = session } }
    func current() -> RuntimeSession<RuntimeReplacementHandler>? { storage.withLock { $0.session } }
    func retire() {
        let owner = storage.withLock { $0.session }
        let snapshot = owner?.snapshot()
        storage.withLock { $0.retired += 1; $0.snapshot = snapshot }
    }
    func evidence() -> (Int, RuntimeAcceptedState?) { storage.withLock { ($0.retired, $0.snapshot) } }
}

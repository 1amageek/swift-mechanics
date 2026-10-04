import Synchronization
import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class NonlinearTestCapture: Sendable {
    private let state=Mutex<NonlinearMechanismState?>(nil)
    func store(_ result:NonlinearMechanismState) { state.withLock { $0=result } }
    func read() -> NonlinearMechanismState? { state.withLock { $0 } }
}

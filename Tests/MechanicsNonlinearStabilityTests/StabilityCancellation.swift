import SwiftMechanics
import Synchronization

@available(macOS 15.0, *)
final class StabilityCancellation: Sendable {
    let storage=Mutex(false)
    func read() -> Bool { storage.withLock{$0} }
    func cancel() { storage.withLock{$0=true} }
}

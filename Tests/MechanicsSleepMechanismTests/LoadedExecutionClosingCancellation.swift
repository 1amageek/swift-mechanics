import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class LoadedExecutionClosingCancellation: Sendable {
    private let storage=Mutex<StationaryLoadExecution?>(nil)
    func bind(_ execution:StationaryLoadExecution) { storage.withLock { $0=execution } }
    func closeDuringCallback() -> Bool {
        let execution=storage.withLock { state in let value=state;state=nil;return value }
        if let execution { _=execution.close() }
        return false
    }
}

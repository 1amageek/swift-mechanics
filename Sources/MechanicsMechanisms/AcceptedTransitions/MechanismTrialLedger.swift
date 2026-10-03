import Synchronization
import MechanicsNumerics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class MechanismTrialLedger: Sendable {
    private let storage:Mutex<NumericalWork>
    init(_ value:NumericalWork) { storage=Mutex(value) }
    func read() -> NumericalWork { storage.withLock { $0 } }
    func store(_ value:NumericalWork) { storage.withLock { $0=value } }
}

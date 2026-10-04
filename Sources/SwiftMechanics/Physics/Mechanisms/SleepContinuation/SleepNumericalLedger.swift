import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class SleepNumericalLedger:Sendable {
    private let storage:Mutex<NumericalWork>
    init(_ work:NumericalWork) { storage=Mutex(work) }
    func read() -> NumericalWork { storage.withLock { $0 } }
    func store(_ work:NumericalWork) { storage.withLock { $0=work } }
}

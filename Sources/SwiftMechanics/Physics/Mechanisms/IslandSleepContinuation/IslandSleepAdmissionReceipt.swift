import Synchronization
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandSleepAdmissionReceipt: Sendable {
    private let storage=Mutex<IslandSleepWork?>(nil)
    func read() -> IslandSleepWork? { storage.withLock { $0 } }
    func store(_ value:IslandSleepWork) { storage.withLock { $0=value } }
}

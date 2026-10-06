import Synchronization
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandSleepReentryEvidence: Sendable {
    private let storage=Mutex<Bool?>(nil)
    var value:Bool? { storage.withLock { $0 } }
    func record(_ value:Bool) { storage.withLock { $0=value } }
}

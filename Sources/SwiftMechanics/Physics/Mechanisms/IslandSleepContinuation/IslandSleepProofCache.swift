import Synchronization
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandSleepProofCache: Sendable {
    private let storage:Mutex<[StationaryIslandRestCertificate?]>
    init(count:Int) { storage=Mutex([StationaryIslandRestCertificate?](repeating:nil,count:count)) }
    func read(_ index:Int) -> StationaryIslandRestCertificate? { storage.withLock { $0[index] } }
    func store(_ proof:StationaryIslandRestCertificate?,at index:Int) { storage.withLock { $0[index]=proof } }
}

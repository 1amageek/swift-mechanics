import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class LoadedSleepProofStorage:Sendable {
    private let storage=Mutex<LoadedSleepRestProof?>(nil)
    func read(position:[Double],drive:[Double],selection:StationaryLoadSelection) -> LoadedSleepRestProof? {
        storage.withLock { value in guard let value,value.position == position,value.drive == drive,value.selection == selection else { return nil };return value }
    }
    func store(_ value:LoadedSleepRestProof?) { storage.withLock { $0=value } }
}

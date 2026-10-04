import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class MechanismSleepMemo: Sendable {
    private let storage=Mutex<MechanismSleepRestCertificate?>(nil)
    func read(position:[Double],drive:[Double]) -> MechanismSleepRestCertificate? {
        storage.withLock { value in
            guard let value,value.position == position,value.drive == drive else { return nil };return value
        }
    }
    func store(_ value:MechanismSleepRestCertificate) { storage.withLock { $0=value } }
}

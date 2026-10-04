import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class SleepPreparedProof:Sendable {
    private let storage=Mutex<MechanismSleepRestCertificate?>(nil)
    func read() -> MechanismSleepRestCertificate? { storage.withLock { $0 } }
    func store(_ proof:MechanismSleepRestCertificate?) { storage.withLock { $0=proof } }
}

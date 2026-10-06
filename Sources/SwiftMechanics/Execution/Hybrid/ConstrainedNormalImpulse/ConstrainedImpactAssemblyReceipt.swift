import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class ConstrainedImpactAssemblyReceipt: Sendable {
    private let storage = Mutex<ConstrainedImpactError?>(nil)
    var failure: ConstrainedImpactError? { storage.withLock { $0 } }
    func record(_ failure: ConstrainedImpactError) { storage.withLock { $0 = failure } }
}

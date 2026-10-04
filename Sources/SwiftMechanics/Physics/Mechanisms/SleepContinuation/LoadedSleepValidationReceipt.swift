import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class LoadedSleepValidationReceipt:Sendable {
    private let storage=Mutex<StationaryLoadWorkReport?>(nil)
    func store(_ value:StationaryLoadWorkReport) { storage.withLock { $0=value } }
    func read() -> StationaryLoadWorkReport {
        if let value=storage.withLock({$0}) { return value }
        // No required load validation invocation was admitted on this failure prefix.
        return StationaryLoadWorkReport(scope:.checkpointAdmission,admission:.notAdmitted,maximumWork:0,maximumScalars:0,maximumInvocations:1,consumed:0,peakScalars:0,invocationsStarted:0,invocationsCompleted:0,failedSupplierWorkUnavailable:false)
    }
}

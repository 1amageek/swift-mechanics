import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class SensorBatchLease: Sendable {
    public let epoch: UInt64
    private let batch: SensorBatch
    private let lifecycle: SensorPipelineLifecycle
    private let active = Mutex(true)
    internal init(batch: SensorBatch, epoch: UInt64, lifecycle: SensorPipelineLifecycle) {
        self.batch = batch; self.epoch = epoch; self.lifecycle = lifecycle
    }
    public func read(_ operation: @Sendable (SensorBatch) throws(SensorPipelineFailure) -> Void) throws(SensorPipelineFailure) {
        guard active.withLock({ $0 }) else { throw .invalidLease }
        try lifecycle.acquireCallback(epoch: epoch)
        defer { lifecycle.releaseCallback() }
        guard active.withLock({ $0 }) else { throw .invalidLease }
        // The immutable backing is retained for the complete callback even if close races.
        try operation(batch)
    }
    internal func close() { active.withLock { $0 = false } }
    deinit { close() }
}

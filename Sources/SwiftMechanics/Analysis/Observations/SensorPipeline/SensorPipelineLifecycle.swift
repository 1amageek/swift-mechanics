import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class SensorPipelineLifecycle: Sendable {
    struct Metadata: Sendable {
        var mutation = false; var readers = 0; var callbacks = 0; var epoch: UInt64 = 0; var closing = false
        var runtimeReleased = false; var releaseIssued = false
    }
    private let storage = Mutex(Metadata())
    let maximumReaders: Int
    private let onRelease: (@Sendable () -> Void)?
    init(maximumReaders: Int, onRelease: (@Sendable () -> Void)?) { self.maximumReaders = maximumReaders; self.onRelease = onRelease }
    func acquireMutation() throws(SensorPipelineFailure) {
        try storage.withLock { (value: inout Metadata) throws(SensorPipelineFailure) in
            guard !value.closing else { throw .closed }
            guard !value.mutation, value.readers == 0, value.callbacks == 0 else { throw .busy }
            value.mutation = true
        }
    }
    func releaseMutation() { let issue = storage.withLock { $0.mutation = false; return release(&$0) }; if issue { onRelease?() } }
    func advancedEpoch() throws(SensorPipelineFailure) {
        try storage.withLock { (value: inout Metadata) throws(SensorPipelineFailure) in
            guard value.epoch < UInt64.max else { throw .capacityExceeded }; value.epoch += 1
        }
    }
    func acquireRead() throws(SensorPipelineFailure) -> UInt64 {
        try storage.withLock { (value: inout Metadata) throws(SensorPipelineFailure) in
            guard !value.closing else { throw .closed }
            guard !value.mutation else { throw .busy }
            guard value.readers < maximumReaders else { throw .capacityExceeded }
            value.readers += 1; return value.epoch
        }
    }
    func releaseRead() { let issue = storage.withLock { $0.readers -= 1; return release(&$0) }; if issue { onRelease?() } }
    func acquireCallback(epoch: UInt64) throws(SensorPipelineFailure) {
        try storage.withLock { (value: inout Metadata) throws(SensorPipelineFailure) in
            guard value.epoch == epoch, !value.closing else { throw .invalidLease }
            guard !value.mutation else { throw .busy }
            guard value.callbacks < maximumReaders else { throw .capacityExceeded }
            value.callbacks += 1
        }
    }
    func releaseCallback() { let issue = storage.withLock { $0.callbacks -= 1; return release(&$0) }; if issue { onRelease?() } }
    func runtimeDidRelease() { let issue = storage.withLock { $0.runtimeReleased = true; return release(&$0) }; if issue { onRelease?() } }
    private func release(_ value: inout Metadata) -> Bool {
        guard value.runtimeReleased, !value.releaseIssued, !value.mutation, value.readers == 0, value.callbacks == 0 else { return false }
        value.releaseIssued = true; return true
    }
    func close() { storage.withLock { $0.closing = true } }
    var hasReaders: Bool { storage.withLock { $0.readers > 0 || $0.callbacks > 0 || $0.mutation } }
}

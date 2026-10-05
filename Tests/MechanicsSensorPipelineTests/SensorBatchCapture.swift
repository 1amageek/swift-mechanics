import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
final class SensorBatchCapture: Sendable {
    private let storage = Mutex<SensorBatch?>(nil)
    func capture(_ session: SensorPipelineFixtures.Session, after: UInt64 = 0) throws -> SensorBatch {
        try session.readBatch(SensorPipelineFixtures.request(session, after: after)) { (lease: SensorBatchLease) throws(SensorPipelineFailure) in
            try lease.read { (batch: SensorBatch) throws(SensorPipelineFailure) in self.storage.withLock { $0 = batch } }
        }
        guard let result = storage.withLock({ $0 }) else { throw SensorPipelineFailure.corruptState }
        return result
    }
}

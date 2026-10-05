@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol SensorPipelineOperating: RuntimeModelReplacing {
    func readBatch(_ request: SensorBatchReadRequest,
                   operation: @Sendable (SensorBatchLease) throws(SensorPipelineFailure) -> Void) throws(SensorPipelineFailure)
}

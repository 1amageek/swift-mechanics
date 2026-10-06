public struct SensorChannel: Sendable {
    public enum EncoderQuantity: UInt64, Sendable { case position, coordinateRate, velocity, acceleration }
    public enum IMUQuantity: UInt64, Sendable { case angularVelocity, specificForce }
    public enum Source: Sendable {
        case encoder(joint: EntityID, quantity: EncoderQuantity, axis: Int)
        case imu(mount: ObservationMount, quantity: IMUQuantity, axis: Int, gravityWorld: Vector3)
        case wrench, range, trigger, tactile
    }
    public let id: String
    public let streamKey: UInt64
    public let source: Source
    public let dimension: PhysicalDimension
    public let processing: SensorProcessing
    public init(id: String, streamKey: UInt64, source: Source, dimension: PhysicalDimension,
                processing: SensorProcessing) throws(SensorPipelineFailure) {
        guard !id.isEmpty else { throw .invalidDefinition }
        self.id = id; self.streamKey = streamKey; self.source = source; self.dimension = dimension; self.processing = processing
    }
}

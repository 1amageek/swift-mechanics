public final class SensorBatch: Sendable {
    public let schema: String
    public let version: UInt64
    public let world: String
    public let model: ModelStamp
    public let channels: [SensorChannel]
    public let records: [SensorRecord]
    public let retainedAfter: UInt64
    public let lastReadySequence: UInt64
    internal init(definition: SensorPipelineDefinition, model: ModelStamp, records: [SensorRecord], floor: UInt64, last: UInt64) {
        schema = definition.schemaID; version = definition.version; world = definition.world
        self.model = model; channels = definition.channels; self.records = records; retainedAfter = floor; lastReadySequence = last
    }
    public func requireCompatible(schema: String, version: UInt64, channelIDs: [String], dimensions: [PhysicalDimension]) throws(SensorPipelineFailure) {
        guard schema == self.schema, version == self.version, channelIDs.count == channels.count, dimensions.count == channels.count else { throw .incompatibleSchema }
        for i in channels.indices { guard channelIDs[i] == channels[i].id, dimensions[i] == channels[i].dimension else { throw .incompatibleSchema } }
    }
}

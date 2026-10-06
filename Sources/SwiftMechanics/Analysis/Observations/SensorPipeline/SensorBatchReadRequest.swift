public struct SensorBatchReadRequest: Sendable {
    public let schema: String
    public let version: UInt64
    public let world: String
    public let model: ModelStamp
    public let after: UInt64
    public let maximumRows: Int
    public let maximumScalars: Int
    public init(schema: String, version: UInt64, world: String, model: ModelStamp, after: UInt64,
                maximumRows: Int, maximumScalars: Int) throws(SensorPipelineFailure) {
        guard !schema.isEmpty, version > 0, !world.isEmpty, maximumRows >= 0, maximumScalars >= 0 else { throw .invalidDefinition }
        self.schema = schema; self.version = version; self.world = world; self.model = model; self.after = after
        self.maximumRows = maximumRows; self.maximumScalars = maximumScalars
    }
}

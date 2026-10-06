public struct ExternalCommandPacket: Equatable, Sendable {
    public let producer: String
    public let model: ModelStamp
    public let actuator: EntityID
    public let configurationRevision: UInt64
    public let sequence: UInt64
    public let sourceTimeSeconds: Double
    public let arrivalTimeSeconds: Double
    public let unit: UnitDefinition
    public let value: Double
    public init(producer: String, model: ModelStamp, actuator: EntityID, configurationRevision: UInt64,
                sequence: UInt64, sourceTimeSeconds: Double, arrivalTimeSeconds: Double,
                unit: UnitDefinition, value: Double) {
        self.producer = producer; self.model = model; self.actuator = actuator
        self.configurationRevision = configurationRevision; self.sequence = sequence
        self.sourceTimeSeconds = sourceTimeSeconds; self.arrivalTimeSeconds = arrivalTimeSeconds
        self.unit = unit; self.value = value
    }
}

public struct ExternalCommandCheckpoint: Sendable {
    public let stream: ExternalCommandStream
    public let packets: [ExternalCommandPacket]
    public let valuesInSI: [Double]
    public let lastTick: UInt64?
    public let lastTargetTimeSeconds: Double?
    internal init(stream: ExternalCommandStream, packets: [ExternalCommandPacket], valuesInSI: [Double],
                  lastTick: UInt64?, lastTargetTimeSeconds: Double?) {
        self.stream = stream; self.packets = packets; self.valuesInSI = valuesInSI
        self.lastTick = lastTick; self.lastTargetTimeSeconds = lastTargetTimeSeconds
    }
}

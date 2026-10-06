public final class SensorRecord: Sendable {
    public let channelIndex: Int
    public let tick: UInt64
    public let sampleTime: Double
    public let sourceTime: Double
    public let source: SensorPhysicalSource
    public let bracketEnd: SensorPhysicalSource?
    public let rawBefore: Double
    public let rawAfter: Double
    public let rawValue: Double
    public let value: Double?
    public let saturated: Bool
    public let releaseDeadline: Double
    public let deliveryTime: Double?
    public let readySequence: UInt64
    public var isDropout: Bool { value == nil }
    public var isInterpolated: Bool { bracketEnd != nil }
    internal init(channel: Int, tick: UInt64, sampleTime: Double, sourceTime: Double, source: SensorPhysicalSource,
                  bracketEnd: SensorPhysicalSource?, rawBefore: Double, rawAfter: Double, rawValue: Double,
                  value: Double?, saturated: Bool, deadline: Double, deliveryTime: Double?, readySequence: UInt64) {
        channelIndex = channel; self.tick = tick; self.sampleTime = sampleTime; self.sourceTime = sourceTime; self.source = source
        self.bracketEnd = bracketEnd; self.rawBefore = rawBefore; self.rawAfter = rawAfter; self.rawValue = rawValue
        self.value = value; self.saturated = saturated; releaseDeadline = deadline; self.deliveryTime = deliveryTime; self.readySequence = readySequence
    }
    internal func delivered(at time: Double, sequence: UInt64) -> SensorRecord {
        SensorRecord(channel: channelIndex, tick: tick, sampleTime: sampleTime, sourceTime: sourceTime, source: source,
            bracketEnd: bracketEnd, rawBefore: rawBefore, rawAfter: rawAfter, rawValue: rawValue,
            value: value, saturated: saturated, deadline: releaseDeadline, deliveryTime: time, readySequence: sequence)
    }
}

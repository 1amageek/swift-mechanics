internal struct SensorPipelineState: Sendable {
    var source: SensorPhysicalSource
    var nextTick: UInt64
    var draws: [UInt64]
    var pending: [SensorRecord]
    var ready: [SensorRecord]
    var lastReady: UInt64
    var floor: UInt64
}

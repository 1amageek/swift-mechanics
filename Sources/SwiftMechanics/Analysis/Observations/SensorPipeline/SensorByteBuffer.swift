internal struct SensorByteBuffer {
    var bytes: [UInt8]
    var cursor = 0
    let maximum: Int
    init(maximum: Int, bytes: [UInt8] = []) throws(SensorPipelineFailure) {
        guard maximum >= 0, bytes.count <= maximum else { throw .capacityExceeded }
        self.maximum = maximum; self.bytes = bytes
    }
    mutating func append(_ value: UInt64) throws(SensorPipelineFailure) {
        guard bytes.count <= maximum, maximum - bytes.count >= 8 else { throw .capacityExceeded }
        for i in 0..<8 { bytes.append(UInt8(truncatingIfNeeded: value >> (8*i))) }
    }
    mutating func append(_ value: Double) throws(SensorPipelineFailure) { try append(value.bitPattern) }
    mutating func append(_ value: Int) throws(SensorPipelineFailure) {
        guard value >= 0 else { throw .invalidDefinition }; try append(UInt64(value))
    }
    mutating func append(_ value: [UInt8]) throws(SensorPipelineFailure) {
        try append(value.count)
        guard value.count <= maximum - bytes.count else { throw .capacityExceeded }
        bytes.append(contentsOf: value)
    }
    mutating func append(_ value: String) throws(SensorPipelineFailure) { try append(Array(value.utf8)) }
    mutating func integer() throws(SensorPipelineFailure) -> UInt64 {
        guard cursor <= bytes.count, bytes.count - cursor >= 8 else { throw .corruptState }
        var result: UInt64 = 0
        for i in 0..<8 { result |= UInt64(bytes[cursor+i]) << (8*i) }
        cursor += 8; return result
    }
    mutating func count(maximum: Int) throws(SensorPipelineFailure) -> Int {
        let result = try integer()
        guard maximum >= 0, result <= UInt64(maximum) else { throw .capacityExceeded }
        return Int(result)
    }
    mutating func scalar() throws(SensorPipelineFailure) -> Double {
        let result = Double(bitPattern: try integer()); guard result.isFinite else { throw .corruptState }; return result
    }
    mutating func payload(maximum: Int) throws(SensorPipelineFailure) -> [UInt8] {
        let count = try self.count(maximum: maximum)
        guard count <= bytes.count - cursor else { throw .corruptState }
        let result = Array(bytes[cursor..<(cursor+count)]); cursor += count; return result
    }
    mutating func flag() throws(SensorPipelineFailure) -> Bool {
        let result = try integer(); guard result <= 1 else { throw .corruptState }; return result == 1
    }
}

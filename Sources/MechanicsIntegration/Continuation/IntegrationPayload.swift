import MechanicsRuntime

internal struct IntegrationPayload {
    var bytes: [UInt8]
    private var offset: Int = 0
    init(bytes: [UInt8] = []) { self.bytes = bytes }
    mutating func put(_ integer: UInt64) { for i in 0..<8 { bytes.append(UInt8(truncatingIfNeeded: integer >> (8*i))) } }
    mutating func put(_ value: Double) { put(value.bitPattern) }
    mutating func put(_ text: String) { put(UInt64(text.utf8.count)); bytes.append(contentsOf: text.utf8) }
    mutating func integer() throws(RuntimeFailure) -> UInt64 {
        guard bytes.count - offset >= 8 else { throw RuntimeFailure(.invalidContributor, message: "Integration history is truncated.") }
        var result: UInt64 = 0
        for i in 0..<8 { result |= UInt64(bytes[offset+i]) << (8*i) }; offset += 8; return result
    }
    mutating func scalar() throws(RuntimeFailure) -> Double {
        let result = Double(bitPattern: try integer())
        guard result.isFinite else { throw RuntimeFailure(.invalidContributor, message: "Integration history contains nonfinite values.") }; return result
    }
    mutating func expect(_ prefix: [UInt8]) throws(RuntimeFailure) {
        guard bytes.count >= prefix.count, bytes.prefix(prefix.count).elementsEqual(prefix) else { throw RuntimeFailure(.incompatibleContinuation, message: "Integration equation/chart/method/options signature changed.") }; offset = prefix.count
    }
    var isAtEnd: Bool { offset == bytes.count }
}

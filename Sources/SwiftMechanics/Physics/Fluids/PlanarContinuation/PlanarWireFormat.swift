internal struct PlanarWireFormat {
    static func sum(_ a: Int, _ b: Int) throws(PlanarContinuationError) -> Int {
        let (value, overflow) = a.addingReportingOverflow(b)
        guard a >= 0, b >= 0, !overflow else { throw .capacity }; return value
    }
    static func product(_ a: Int, _ b: Int) throws(PlanarContinuationError) -> Int {
        let (value, overflow) = a.multipliedReportingOverflow(by: b)
        guard a >= 0, b >= 0, !overflow else { throw .capacity }; return value
    }
    static func append(_ value: UInt64, bytes: inout [UInt8], maximum: Int) throws(PlanarContinuationError) {
        guard maximum >= 8, bytes.count <= maximum - 8 else { throw .capacity }
        for i in 0..<8 { bytes.append(UInt8(truncatingIfNeeded: value >> (8*i))) }
    }
    static func append(_ text: String, bytes: inout [UInt8], maximum: Int) throws(PlanarContinuationError) {
        try append(UInt64(text.utf8.count), bytes: &bytes, maximum: maximum)
        for byte in text.utf8 { guard bytes.count < maximum else { throw .capacity }; bytes.append(byte) }
    }
    static func put(_ value: UInt64, bytes: inout [UInt8], cursor: inout Int) {
        for i in 0..<8 { bytes[cursor+i] = UInt8(truncatingIfNeeded: value >> (8*i)) }; cursor += 8
    }
    static func read(_ bytes: [UInt8], cursor: inout Int) -> UInt64 {
        var value: UInt64 = 0
        for i in 0..<8 { value |= UInt64(bytes[cursor+i]) << (8*i) }; cursor += 8; return value
    }
}

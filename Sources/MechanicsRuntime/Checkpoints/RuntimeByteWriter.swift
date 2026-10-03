internal struct RuntimeByteWriter {
    private(set) var bytes: [UInt8] = []
    private let maximum: Int
    init(maximum: Int, reservation: Int) { self.maximum = maximum; bytes.reserveCapacity(reservation) }
    mutating func append(_ byte: UInt8) throws(RuntimeFailure) {
        guard bytes.count < maximum else { throw RuntimeFailure(.capacityExceeded, message: "Encoded checkpoint exceeds byte capacity.") }; bytes.append(byte)
    }
    mutating func integer(_ value: UInt64) throws(RuntimeFailure) {
        for i in 0..<8 { try append(UInt8(truncatingIfNeeded: value >> (i * 8))) }
    }
    mutating func string(_ value: String) throws(RuntimeFailure) {
        try integer(UInt64(value.utf8.count)); for byte in value.utf8 { try append(byte) }
    }
    mutating func doubles(_ values: [Double]) throws(RuntimeFailure) {
        try integer(UInt64(values.count)); for value in values { guard value.isFinite else { throw RuntimeFailure(.invalidState, message: "Checkpoint scalar is nonfinite.") }; try integer(value.bitPattern) }
    }
}

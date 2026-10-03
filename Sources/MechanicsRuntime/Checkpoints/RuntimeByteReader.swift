@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct RuntimeByteReader {
    private let bytes: ArraySlice<UInt8>
    private var offset: Int
    private let capacity: RuntimeCapacity
    private var scalarCount = 0
    private var metadataCount = 0
    private var payloadCount = 0
    init(bytes: ArraySlice<UInt8>, capacity: RuntimeCapacity) { self.bytes = bytes; offset = bytes.startIndex; self.capacity = capacity }
    var remaining: Int { bytes.endIndex - offset }
    mutating func byte() throws(RuntimeFailure) -> UInt8 {
        guard remaining > 0 else { throw RuntimeFailure(.truncatedCheckpoint, message: "Checkpoint ended during field read.") }
        defer { offset += 1 }; return bytes[offset]
    }
    mutating func integer() throws(RuntimeFailure) -> UInt64 {
        guard remaining >= 8 else { throw RuntimeFailure(.truncatedCheckpoint, message: "Checkpoint ended during integer read.") }
        var value: UInt64 = 0
        for i in 0..<8 { value |= UInt64(try byte()) << (i * 8) }; return value
    }
    mutating func count(maximum: Int) throws(RuntimeFailure) -> Int {
        let raw = try integer()
        guard let value = Int(exactly: raw), value <= maximum else { throw RuntimeFailure(.capacityExceeded, message: "Encoded count exceeds capacity.") }; return value
    }
    mutating func string() throws(RuntimeFailure) -> String {
        let length = try count(maximum: capacity.maximumMetadataBytes)
        metadataCount = try RuntimeCounts.sum(metadataCount, length)
        guard metadataCount <= capacity.maximumMetadataBytes else { throw RuntimeFailure(.capacityExceeded, message: "Decoded metadata exceeds capacity.") }
        guard length <= remaining else { throw RuntimeFailure(.truncatedCheckpoint, message: "String field is truncated.") }
        let end = offset + length
        guard let value = String(validating: bytes[offset..<end], as: UTF8.self) else { throw RuntimeFailure(.corruptCheckpoint, message: "String field is not valid UTF-8.") }
        offset = end; return value
    }
    mutating func doubles() throws(RuntimeFailure) -> [Double] {
        let count = try count(maximum: capacity.maximumPhysicalScalars)
        scalarCount = try RuntimeCounts.sum(scalarCount, count)
        guard scalarCount <= capacity.maximumPhysicalScalars, count <= remaining / 8 else { throw RuntimeFailure(.capacityExceeded, message: "Decoded scalar count exceeds capacity or available bytes.") }
        var values: [Double] = []; values.reserveCapacity(count)
        for _ in 0..<count {
            let value = Double(bitPattern: try integer())
            guard value.isFinite else { throw RuntimeFailure(.corruptCheckpoint, message: "Decoded scalar is nonfinite.") }; values.append(value)
        }; return values
    }
    mutating func payload() throws(RuntimeFailure) -> [UInt8] {
        let count = try count(maximum: capacity.maximumContributorBytes)
        payloadCount = try RuntimeCounts.sum(payloadCount, count)
        guard payloadCount <= capacity.maximumContributorBytes else { throw RuntimeFailure(.capacityExceeded, message: "Decoded contributor bytes exceed capacity.") }
        guard count <= remaining else { throw RuntimeFailure(.truncatedCheckpoint, message: "Contributor payload is truncated.") }
        let end = offset + count
        let value = Array(bytes[offset..<end]); offset = end; return value
    }
}


internal struct HybridPayload {
    var bytes: [UInt8]=[]
    var cursor=0
    mutating func put(_ value: UInt64) { for i in 0..<8 { bytes.append(UInt8(truncatingIfNeeded:value >> (i*8))) } }
    mutating func put(_ value: Double) { put(value.bitPattern) }
    mutating func get() throws(RuntimeFailure) -> UInt64 {
        guard cursor <= bytes.count, bytes.count-cursor >= 8 else { throw RuntimeFailure(.invalidContributor,message:"Truncated hybrid continuation.") }
        var value: UInt64=0
        for i in 0..<8 { value |= UInt64(bytes[cursor+i]) << (i*8) }; cursor += 8; return value
    }
    mutating func scalar() throws(RuntimeFailure) -> Double {
        let value=Double(bitPattern:try get()); guard value.isFinite else { throw RuntimeFailure(.invalidContributor,message:"Nonfinite hybrid continuation.") }; return value
    }
    mutating func expect(_ signature: [UInt8]) throws(RuntimeFailure) {
        guard bytes.count >= signature.count else { throw RuntimeFailure(.invalidContributor,message:"Truncated hybrid signature.") }
        for i in signature.indices { guard bytes[i] == signature[i] else { throw RuntimeFailure(.incompatibleContinuation,message:"Hybrid model/chart/geometry/policy signature differs.") } }
        cursor=signature.count
    }
}

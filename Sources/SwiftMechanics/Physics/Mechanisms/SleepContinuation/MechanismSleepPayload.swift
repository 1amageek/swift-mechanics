internal struct MechanismSleepPayload {
    var bytes:[UInt8]
    private var cursor=0
    init(bytes:[UInt8] = []) { self.bytes=bytes }
    var isAtEnd:Bool { cursor == bytes.count }
    mutating func put(_ value:UInt64) { for shift in stride(from:0,to:64,by:8) { bytes.append(UInt8(truncatingIfNeeded:value >> shift)) } }
    mutating func put(_ value:Double) { put(value.bitPattern) }
    mutating func integer() throws(RuntimeFailure) -> UInt64 {
        guard cursor <= bytes.count,bytes.count-cursor >= 8 else { throw RuntimeFailure(.invalidContributor,message:"Truncated sleep continuation.") }
        var value:UInt64=0
        for i in 0..<8 { value |= UInt64(bytes[cursor+i]) << (8*i) };cursor+=8;return value
    }
    mutating func scalar() throws(RuntimeFailure) -> Double {
        let value=Double(bitPattern:try integer())
        guard value.isFinite else { throw RuntimeFailure(.invalidContributor,message:"Nonfinite sleep continuation scalar.") };return value
    }
    mutating func flag() throws(RuntimeFailure) -> Bool {
        let value=try integer();guard value <= 1 else { throw RuntimeFailure(.invalidContributor,message:"Invalid sleep flag.") };return value == 1
    }
}

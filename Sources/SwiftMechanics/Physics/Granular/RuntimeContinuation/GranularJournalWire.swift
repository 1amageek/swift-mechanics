internal enum GranularJournalWire {
    static func sum(_ a: Int,_ b: Int) throws(GranularRuntimeError) -> Int {
        let (value,overflow)=a.addingReportingOverflow(b);guard a >= 0,b >= 0,!overflow else { throw .capacityExceeded };return value
    }
    static func product(_ a: Int,_ b: Int) throws(GranularRuntimeError) -> Int {
        let (value,overflow)=a.multipliedReportingOverflow(by:b);guard a >= 0,b >= 0,!overflow else { throw .capacityExceeded };return value
    }
    static func word(_ value: UInt64,bytes: inout [UInt8],maximum: Int,work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        guard maximum >= 8,bytes.count <= maximum-8 else { throw .capacityExceeded };try work.charge(8)
        for i in 0..<8 { bytes.append(UInt8(truncatingIfNeeded:value >> (8*i))) }
    }
    static func text(_ value: String,bytes: inout [UInt8],maximum: Int,remaining: inout Int,work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        guard !value.isEmpty else { throw .invalidInput }
        var count=0
        for _ in value.utf8 { try work.charge(3);guard remaining > 0 else { throw .capacityExceeded };remaining-=1;count+=1 }
        try word(UInt64(count),bytes:&bytes,maximum:maximum,work:&work)
        for byte in value.utf8 { guard bytes.count < maximum else { throw .capacityExceeded };bytes.append(byte) }
    }
    static func read(_ bytes: [UInt8],cursor: inout Int) -> UInt64 {
        var value: UInt64=0;for i in 0..<8 { value |= UInt64(bytes[cursor+i]) << (8*i) };cursor+=8;return value
    }
    static func same(_ a: GranularState,_ b: GranularState) -> Bool {
        guard a.model === b.model,a.motions == b.motions,a.timeSeconds.bitPattern == b.timeSeconds.bitPattern,
              a.steps == b.steps,a.random == b.random,a.contacts.count == b.contacts.count else { return false }
        for i in a.contacts.indices { guard a.contacts[i].history == b.contacts[i].history,a.contacts[i].basis == b.contacts[i].basis else { return false } }
        return true
    }
}

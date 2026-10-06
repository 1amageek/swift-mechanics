internal enum ConstrainedSleepBytes {
    static func put(_ word:UInt64,into bytes:inout [UInt8]) { for shift in stride(from:0,to:64,by:8) { bytes.append(UInt8(truncatingIfNeeded:word >> shift)) } }
    static func sum(_ x:Int,_ y:Int) throws(RuntimeFailure) -> Int { let (n,o)=x.addingReportingOverflow(y);guard x>=0,y>=0,!o else { throw RuntimeFailure(.capacityExceeded,message:"Event byte count overflow.") };return n }
    static func product(_ x:Int,_ y:Int) throws(RuntimeFailure) -> Int { let (n,o)=x.multipliedReportingOverflow(by:y);guard x>=0,y>=0,!o else { throw RuntimeFailure(.capacityExceeded,message:"Event byte product overflow.") };return n }
    static func take(_ bytes:[UInt8],at offset:inout Int) throws(RuntimeFailure) -> UInt64 {
        guard offset>=0,bytes.count>=8,offset<=bytes.count-8 else { throw RuntimeFailure(.invalidContributor,message:"Truncated constrained event history.") }
        var value:UInt64=0;for k in 0..<8 { value |= UInt64(bytes[offset+k]) << (8*k) };offset+=8;return value
    }
    static func equal(_ x:[Double],_ y:[Double]) -> Bool { x.count == y.count && zip(x,y).allSatisfy({$0.bitPattern == $1.bitPattern}) }
}

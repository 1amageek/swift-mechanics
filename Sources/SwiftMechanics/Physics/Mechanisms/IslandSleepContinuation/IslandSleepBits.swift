internal enum IslandSleepBits {
    static func equal(_ x:[Double],_ y:[Double]) -> Bool { x.count == y.count && zip(x,y).allSatisfy({pair in pair.0.bitPattern == pair.1.bitPattern}) }
    static func put(_ word:UInt64,into bytes:inout [UInt8]) { for shift in stride(from:0,to:64,by:8) { bytes.append(UInt8(truncatingIfNeeded:word >> shift)) } }
    static func take(_ bytes:[UInt8],at offset:inout Int) throws(RuntimeFailure) -> UInt64 {
        guard offset >= 0,offset <= bytes.count,bytes.count-offset >= 8 else { throw RuntimeFailure(.invalidContributor,message:"Truncated island history.") }
        var result:UInt64=0;for i in 0..<8 { result |= UInt64(bytes[offset+i]) << (i*8) };offset += 8;return result
    }
    static func sum(_ a:Int,_ b:Int) throws(RuntimeFailure) -> Int { let (r,o)=a.addingReportingOverflow(b);guard a >= 0,b >= 0,!o else { throw RuntimeFailure(.capacityExceeded,message:"Island count overflow.") };return r }
    static func product(_ a:Int,_ b:Int) throws(RuntimeFailure) -> Int { let (r,o)=a.multipliedReportingOverflow(by:b);guard a >= 0,b >= 0,!o else { throw RuntimeFailure(.capacityExceeded,message:"Island storage overflow.") };return r }
    static func valid(_ x:NumericalWork,_ p:NumericalWork) -> Bool { x.budget == p.budget && x.operations >= p.operations && x.iterations >= p.iterations && x.peakScalarStorage >= p.peakScalarStorage }
}

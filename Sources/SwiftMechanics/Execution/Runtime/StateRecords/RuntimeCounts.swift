internal enum RuntimeCounts {
    static func sum(_ left: Int, _ right: Int) throws(RuntimeFailure) -> Int {
        let (value, overflow) = left.addingReportingOverflow(right)
        guard left >= 0, right >= 0, !overflow else { throw RuntimeFailure(.integerOverflow, message: "Runtime count addition overflow.") }
        return value
    }
    static func physical(q: Int, v: Int) throws(RuntimeFailure) -> Int { try sum(q, sum(v, v)) }
    static func product(_ left:Int,_ right:Int) throws(RuntimeFailure) -> Int {
        let (value,overflow)=left.multipliedReportingOverflow(by:right)
        guard left >= 0,right >= 0,!overflow else { throw RuntimeFailure(.integerOverflow,message:"Runtime count multiplication overflow.") };return value
    }
    static func physical(state:KinematicState) throws(RuntimeFailure) -> Int {
        try sum(physical(q:state.q.count,v:state.v.count),product(20,state.prescribedAnchors.count))
    }
    static func anchorMetadata(state:KinematicState,maximum:Int) throws(RuntimeFailure) -> Int {
        var bytes=0
        for anchor in state.prescribedAnchors {
            bytes=try sum(bytes,anchor.frame.key.utf8.count)
            guard bytes <= maximum else { throw RuntimeFailure(.capacityExceeded,message:"Prescribed frame metadata exceeds capacity.") }
        }
        return bytes
    }
}

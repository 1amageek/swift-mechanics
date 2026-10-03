import MechanicsRuntime

internal struct HybridByteBounds {
    let maximum: Int
    private(set) var bytes=0
    init(maximum: Int) { self.maximum=maximum }
    mutating func reserve(_ count: Int) throws(RuntimeFailure) {
        let (next,overflow)=bytes.addingReportingOverflow(count)
        guard count >= 0, !overflow, next <= maximum else { throw RuntimeFailure(.capacityExceeded,message:"Hybrid serialized capacity exceeded before materialization.") }
        bytes=next
    }
    mutating func words(_ count: Int) throws(RuntimeFailure) {
        let (value,overflow)=count.multipliedReportingOverflow(by:8)
        guard count >= 0, !overflow else { throw RuntimeFailure(.capacityExceeded,message:"Hybrid serialized count overflow.") }
        try reserve(value)
    }
    mutating func text(_ value: String, identifierLimit: Int, prefixed: Bool) throws(RuntimeFailure) -> Int {
        if prefixed { try words(1) }
        let limit=min(identifierLimit,maximum-bytes)
        guard limit >= 0 else { throw RuntimeFailure(.capacityExceeded,message:"Hybrid metadata capacity invalid.") }
        var count=0
        for _ in value.utf8 {
            guard count < limit else { throw RuntimeFailure(.capacityExceeded,message:"Hybrid metadata exceeds bounded UTF-8 traversal.") }
            count += 1
        }
        try reserve(count)
        return count
    }
    static func recordCapacity(identity: String, providerBytes: Int, events: Int, q: Int, v: Int, scales: Int,
                               maximum: Int) throws(RuntimeFailure) -> (total: Int, identityBytes: Int, recordBytes: Int) {
        var bounds=HybridByteBounds(maximum:maximum)
        // 136 signature fixed bytes plus 40 maximum record fixed bytes (optional last time included).
        try bounds.reserve(176)
        try bounds.words(events); try bounds.words(scales)
        try bounds.words(q); try bounds.words(v); try bounds.words(events)
        let identityBytes=try bounds.text(identity,identifierLimit:maximum,prefixed:false)
        try bounds.reserve(providerBytes)
        var record=HybridByteBounds(maximum:maximum); try record.reserve(40)
        try record.words(q); try record.words(v); try record.words(events)
        return (bounds.bytes,identityBytes,record.bytes)
    }
}

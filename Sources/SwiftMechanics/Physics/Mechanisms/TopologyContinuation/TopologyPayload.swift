@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct TopologyPayload {
    var bytes: [UInt8]
    private var offset=0
    private var metadata=0
    private(set) var used=0
    private let policy:TopologyContinuationPolicy
    init(bytes:[UInt8]=[],policy:TopologyContinuationPolicy) throws(TopologyReleaseFailure) {
        guard bytes.count <= policy.maximumBytes,bytes.count <= policy.maximumWork else { throw .capacityExceeded }
        self.bytes=bytes;self.policy=policy;used=bytes.count
    }
    private mutating func charge(_ count:Int) throws(TopologyReleaseFailure) {
        let (next,overflow)=used.addingReportingOverflow(count)
        guard count >= 0,!overflow,next <= policy.maximumWork else { throw .capacityExceeded };used=next
    }
    mutating func put(_ value:UInt64) throws(TopologyReleaseFailure) {
        guard bytes.count <= policy.maximumBytes-8 else { throw .capacityExceeded };try charge(8)
        for shift in stride(from:0,to:64,by:8) { bytes.append(UInt8(truncatingIfNeeded:value >> shift)) }
    }
    mutating func put(_ value:String) throws(TopologyReleaseFailure) {
        let count=value.utf8.count;let (next,overflow)=metadata.addingReportingOverflow(count)
        guard !overflow,next <= policy.maximumMetadataBytes,count <= policy.maximumBytes-bytes.count else { throw .capacityExceeded }
        try put(UInt64(count));guard count <= policy.maximumBytes-bytes.count else { throw .capacityExceeded }
        try charge(count);metadata=next;bytes.append(contentsOf:value.utf8)
    }
    mutating func get() throws(TopologyReleaseFailure) -> UInt64 {
        guard offset <= bytes.count-8 else { throw .invalidInput };try charge(8)
        var result:UInt64=0;for i in 0..<8 { result |= UInt64(bytes[offset+i]) << (8*i) };offset+=8;return result
    }
    mutating func put(_ value:[UInt8]) throws(TopologyReleaseFailure) {
        try put(UInt64(value.count))
        guard value.count <= policy.maximumBytes-bytes.count else { throw .capacityExceeded }
        try charge(value.count);bytes.append(contentsOf:value)
    }
    mutating func text() throws(TopologyReleaseFailure) -> String {
        let n=try get();guard n <= UInt64(Int.max),n <= UInt64(bytes.count-offset) else { throw .invalidInput }
        let count=Int(n);let (next,overflow)=metadata.addingReportingOverflow(count)
        guard !overflow,next <= policy.maximumMetadataBytes else { throw .capacityExceeded };try charge(count)
        guard let result=String(validating:bytes[offset..<offset+count],as:UTF8.self) else { throw .invalidInput }
        offset+=count;metadata=next;return result
    }
    mutating func expect(_ prefix:[UInt8]) throws(TopologyReleaseFailure) {
        guard prefix.count <= bytes.count else { throw .invalidInput };try charge(prefix.count)
        guard bytes[..<prefix.count].elementsEqual(prefix) else { throw .staleSource };offset=prefix.count
    }
    var ended:Bool { offset == bytes.count }
}

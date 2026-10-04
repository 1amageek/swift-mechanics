public struct FixedActuatorContinuationCodec: ActuatorContinuationCoding, Sendable {
    public init() {}
    public func encodedSize(binding:ActuatorBinding,work:inout ActuationWork) throws(ActuationError) -> Int {
        var count=146
        try size(binding.model.identity,count:&count,work:&work);try size(binding.actuator.key,count:&count,work:&work)
        try size(binding.joint.key,count:&count,work:&work);try size(binding.frame.key,count:&count,work:&work)
        try work.reserve(bytes:count);return count
    }
    public func encode(_ state:ActuatorState,work:inout ActuationWork) throws(ActuationError) -> RuntimeContributorState {
        let count=try encodedSize(binding:state.binding,work:&work);try work.charge(count)
        var bytes=[UInt8](repeating:0,count:count)
        put(state.binding.model.revision,at:0,in:&bytes);put(state.binding.lawRevision,at:8,in:&bytes)
        bytes[16]=state.binding.stateKind.rawValue;bytes[17]=state.mode.rawValue
        put(state.time.bitPattern,at:24,in:&bytes);put(state.primary.bitPattern,at:32,in:&bytes);put(state.secondary.bitPattern,at:40,in:&bytes)
        put(state.sequence,at:48,in:&bytes);put(state.binding.continuationKey,at:56,in:&bytes)
        writeBinding(state.binding,in:&bytes)
        do { return try RuntimeContributorState(id:state.binding.actuator.key,category:.actuator,version:1,bytes:bytes) } catch { throw .runtime(error.code) }
    }
    public func decode(_ record:RuntimeContributorState,binding:ActuatorBinding,work:inout ActuationWork) throws(ActuationError) -> ActuatorState {
        try work.metadata(record.id)
        let count=try encodedSize(binding:binding,work:&work);try work.charge(count)
        guard record.id == binding.actuator.key,record.category == .actuator,record.version == 1,record.bytes.count == count else { throw .staleBinding }
        let bytes=record.bytes
        try checkBinding(binding,in:bytes)
        guard read(bytes,at:0) == binding.model.revision,read(bytes,at:8) == binding.lawRevision,bytes[16] == binding.stateKind.rawValue,
              read(bytes,at:56) == binding.continuationKey else { throw .staleBinding }
        for i in 18..<24 { guard bytes[i] == 0 else { throw .invalidInput } }
        guard let mode=DriveMode(rawValue:bytes[17]) else { throw .incompatibleMode }
        return try ActuatorState(binding:binding,time:Double(bitPattern:read(bytes,at:24)),primary:Double(bitPattern:read(bytes,at:32)),
            secondary:Double(bitPattern:read(bytes,at:40)),mode:mode,sequence:read(bytes,at:48))
    }
    private func size(_ text:String,count:inout Int,work:inout ActuationWork) throws(ActuationError) {
        try work.metadata(text);let (next,overflow)=count.addingReportingOverflow(text.utf8.count)
        guard !overflow else { throw .capacityExceeded };count=next
    }
    private func writeText(_ text:String,cursor:inout Int,in bytes:inout [UInt8]) {
        put(UInt64(text.utf8.count),at:cursor,in:&bytes);cursor += 8
        for byte in text.utf8 { bytes[cursor]=byte;cursor += 1 }
    }
    private func checkText(_ text:String,cursor:inout Int,in bytes:[UInt8]) throws(ActuationError) {
        guard read(bytes,at:cursor) == UInt64(text.utf8.count) else { throw .staleBinding };cursor += 8
        for byte in text.utf8 { guard bytes[cursor] == byte else { throw .staleBinding };cursor += 1 }
    }
    private func writeBinding(_ b:ActuatorBinding,in bytes:inout [UInt8]) {
        var cursor=64
        writeText(b.model.identity,cursor:&cursor,in:&bytes);writeText(b.actuator.key,cursor:&cursor,in:&bytes)
        writeText(b.joint.key,cursor:&cursor,in:&bytes);writeText(b.frame.key,cursor:&cursor,in:&bytes)
        put(UInt64(b.positionIndex),at:cursor,in:&bytes);cursor += 8;put(UInt64(b.velocityIndex),at:cursor,in:&bytes);cursor += 8
        bytes[cursor]=b.coordinate == .translation ? 0 : 1;cursor += 1
        bytes[cursor]=b.authority == .fixed ? 0 : (b.authority == .dynamicState ? 1 : 2);cursor += 1
        put(b.stateDomain.primaryLower.bitPattern,at:cursor,in:&bytes);put(b.stateDomain.primaryUpper.bitPattern,at:cursor+8,in:&bytes)
        put(b.stateDomain.secondaryLower.bitPattern,at:cursor+16,in:&bytes);put(b.stateDomain.secondaryUpper.bitPattern,at:cursor+24,in:&bytes)
    }
    private func checkBinding(_ b:ActuatorBinding,in bytes:[UInt8]) throws(ActuationError) {
        var cursor=64
        try checkText(b.model.identity,cursor:&cursor,in:bytes);try checkText(b.actuator.key,cursor:&cursor,in:bytes)
        try checkText(b.joint.key,cursor:&cursor,in:bytes);try checkText(b.frame.key,cursor:&cursor,in:bytes)
        guard read(bytes,at:cursor) == UInt64(b.positionIndex),read(bytes,at:cursor+8) == UInt64(b.velocityIndex) else { throw .staleBinding };cursor += 16
        guard bytes[cursor] == (b.coordinate == .translation ? 0 : 1),bytes[cursor+1] == (b.authority == .fixed ? 0 : (b.authority == .dynamicState ? 1 : 2)) else { throw .staleBinding };cursor += 2
        guard read(bytes,at:cursor) == b.stateDomain.primaryLower.bitPattern,read(bytes,at:cursor+8) == b.stateDomain.primaryUpper.bitPattern,
              read(bytes,at:cursor+16) == b.stateDomain.secondaryLower.bitPattern,read(bytes,at:cursor+24) == b.stateDomain.secondaryUpper.bitPattern else { throw .staleBinding }
    }
    private func put(_ value:UInt64,at offset:Int,in bytes:inout [UInt8]) { for i in 0..<8 { bytes[offset+i]=UInt8(truncatingIfNeeded:value >> (8*i)) } }
    private func read(_ bytes:[UInt8],at offset:Int) -> UInt64 { var value:UInt64=0;for i in 0..<8 { value |= UInt64(bytes[offset+i]) << (8*i) };return value }
}

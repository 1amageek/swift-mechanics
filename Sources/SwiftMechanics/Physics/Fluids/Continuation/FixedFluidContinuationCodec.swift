public struct FixedFluidContinuationCodec: FluidContinuationCoding, Sendable {
    public let channel: FluidChannel
    public let schema: RuntimeContributorSchema
    public let encodedSize: Int
    public let pressureGradientTolerance: Double
    private let signature: [UInt8]
    public init(channel: FluidChannel, contributorID: String, maximumBytes: Int,
                pressureGradientTolerance: Double) throws(FluidError) {
        guard maximumBytes >= 0, pressureGradientTolerance.isFinite, pressureGradientTolerance >= 0,
              !contributorID.isEmpty else { throw .invalidInput }
        var remaining=channel.limits.maximumMetadataBytes
        for text in [channel.id,channel.model.identity,channel.frame.key,channel.source.source,channel.boundaryLaw,contributorID] {
            for _ in text.utf8 { guard remaining > 0 else { throw .capacity }; remaining -= 1 }
        }
        var bytes=[UInt8]()
        // Capacity checks precede every append; all signature data originates from admitted owned context.
        func word(_ value: UInt64) throws(FluidError) {
            guard bytes.count <= maximumBytes-8 else { throw .capacity }
            for i in 0..<8 { bytes.append(UInt8(truncatingIfNeeded:value >> (8*i))) }
        }
        func text(_ value: String) throws(FluidError) {
            try word(UInt64(value.utf8.count))
            for byte in value.utf8 { guard bytes.count < maximumBytes else { throw .capacity }; bytes.append(byte) }
        }
        try word(0x31564c464e4d53); try word(1)
        for value in [channel.id,channel.model.identity,channel.frame.key,channel.source.source,channel.boundaryLaw,contributorID] { try text(value) }
        for value in [channel.revision,channel.model.revision,channel.source.revision,channel.boundaryRevision,UInt64(channel.cells),
                      UInt64(channel.limits.maximumCells),UInt64(channel.limits.maximumMetadataBytes)] { try word(value) }
        for value in [channel.height,channel.wallArea,channel.density,channel.viscosity,channel.accelerationX,channel.accelerationY,
                      channel.limits.maximumSpeed,channel.limits.maximumPressure,channel.limits.maximumSource,channel.limits.maximumStep,pressureGradientTolerance] { try word(value.bitPattern) }
        let (scalars,o1)=channel.cells.multipliedReportingOverflow(by:2)
        let (words,o2)=scalars.addingReportingOverflow(7)
        let (payload,o3)=words.multipliedReportingOverflow(by:8)
        let (count,o4)=bytes.count.addingReportingOverflow(payload)
        guard !o1,!o2,!o3,!o4,count <= maximumBytes else { throw .capacity }
        self.channel=channel; self.signature=bytes; self.encodedSize=count; self.pressureGradientTolerance=pressureGradientTolerance
        do { self.schema=try RuntimeContributorSchema(id:contributorID,category:.integrator,version:1,maximumBytes:count) }
        catch { throw .runtime(error.code) }
    }
    public func encode(_ state: FluidState, work: inout FluidByteWork) throws(FluidError) -> RuntimeContributorState {
        try reserve(work:&work); try work.visit(encodedSize)
        guard state.channel == channel else { throw .staleBinding }; try validate(state)
        var bytes=[UInt8](repeating:0,count:encodedSize)
        for i in signature.indices { bytes[i]=signature[i] }
        var cursor=signature.count
        put(state.time.bitPattern,cursor:&cursor,bytes:&bytes); put(state.sequence,cursor:&cursor,bytes:&bytes)
        for value in [state.boundary.lowerSpeed,state.boundary.upperSpeed,state.boundary.pressureGradientX,state.boundary.lowerGaugePressure] { put(value.bitPattern,cursor:&cursor,bytes:&bytes) }
        for value in state.velocities { put(value.bitPattern,cursor:&cursor,bytes:&bytes) }
        for value in state.pressureFaces { put(value.bitPattern,cursor:&cursor,bytes:&bytes) }
        do { return try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:bytes) }
        catch { throw .runtime(error.code) }
    }
    public func decode(_ record: RuntimeContributorState, work: inout FluidByteWork) throws(FluidError) -> FluidState {
        try reserve(work:&work)
        var metadata=0
        for _ in record.id.utf8 {
            guard metadata < channel.limits.maximumMetadataBytes else { throw .capacity }
            try work.visit(1); metadata += 1
        }
        guard record.id == schema.id,record.category == schema.category,record.version == schema.version,
              record.bytes.count == encodedSize else { throw .staleBinding }
        try work.visit(encodedSize)
        for i in signature.indices { guard signature[i] == record.bytes[i] else { throw .staleBinding } }
        var cursor=signature.count
        let time=Double(bitPattern:read(record.bytes,cursor:&cursor)),sequence=read(record.bytes,cursor:&cursor)
        let lower=Double(bitPattern:read(record.bytes,cursor:&cursor)),upper=Double(bitPattern:read(record.bytes,cursor:&cursor))
        let gradient=Double(bitPattern:read(record.bytes,cursor:&cursor)),pressure=Double(bitPattern:read(record.bytes,cursor:&cursor))
        let boundary=try FluidBoundary(lowerSpeed:lower,upperSpeed:upper,pressureGradientX:gradient,lowerGaugePressure:pressure)
        var u=[Double](repeating:0,count:channel.cells),p=[Double](repeating:0,count:channel.cells+1)
        for i in u.indices { u[i]=Double(bitPattern:read(record.bytes,cursor:&cursor)) }
        for i in p.indices { p[i]=Double(bitPattern:read(record.bytes,cursor:&cursor)) }
        let state=FluidState(channel:channel,boundary:boundary,time:time,sequence:sequence,velocities:u,pressureFaces:p)
        try validate(state); return state
    }
    private func reserve(work: inout FluidByteWork) throws(FluidError) {
        let (scalarBytes,o1)=channel.cells.multipliedReportingOverflow(by:16)
        let (total,o2)=encodedSize.addingReportingOverflow(signature.count)
        let (live,o3)=total.addingReportingOverflow(scalarBytes)
        let (withFace,o4)=live.addingReportingOverflow(8)
        guard !o1,!o2,!o3,!o4 else { throw .capacity }; try work.reserve(withFace)
    }
    private func validate(_ state: FluidState) throws(FluidError) {
        try state.validate()
        guard state.pressureFaces[0] == state.boundary.lowerGaugePressure else { throw .originalResidual }
        for i in 0..<channel.cells {
            let residual=try fluidFinite((state.pressureFaces[i+1]-state.pressureFaces[i])/channel.spacing-channel.density*channel.accelerationY)
            guard abs(residual) <= pressureGradientTolerance else { throw .originalResidual }
        }
    }
    private func put(_ value: UInt64,cursor: inout Int,bytes: inout [UInt8]) {
        for i in 0..<8 { bytes[cursor+i]=UInt8(truncatingIfNeeded:value >> (8*i)) }; cursor += 8
    }
    private func read(_ bytes: [UInt8],cursor: inout Int) -> UInt64 {
        var value:UInt64=0; for i in 0..<8 { value |= UInt64(bytes[cursor+i]) << (8*i) }; cursor += 8; return value
    }
}

public struct SMNXNativeModelCodec: NativeModelCoding, Sendable {
    public init() {}
    public func encode(document:NativeMechanicalDocument,work:inout ExchangeWork) throws(ExchangeError) -> [UInt8] {
        var writer=try NativeWireWriter(work:work,measuring:true)
        defer { work=writer.work }
        try writer.document(document)
        try NativeDocumentAdmission.validate(document,work:&writer.work)
        let measured=writer.size
        writer=try NativeWireWriter(work:writer.work,measuring:false,reservation:measured)
        try writer.document(document)
        guard writer.size == measured else { throw .invalidInput }
        try writer.work.checkCancellation();return writer.bytes
    }
    public func decode(bytes:[UInt8],work:inout ExchangeWork) throws(ExchangeError) -> NativeDecodeResult {
        guard bytes.count <= work.policy.maximumWireBytes else { throw .resourceLimit(resource:.wireBytes,limit:work.policy.maximumWireBytes) }
        var reader=NativeWireReader(bytes:bytes,work:work)
        defer { work=reader.work }
        let document=try reader.document()
        try NativeDocumentAdmission.validate(document,work:&reader.work)
        try reader.work.checkCancellation()
        return NativeDecodeResult(document:document,maximumComponentCorrection:reader.maximumCorrection,correctedUnitRecords:reader.correctedRecords)
    }
}

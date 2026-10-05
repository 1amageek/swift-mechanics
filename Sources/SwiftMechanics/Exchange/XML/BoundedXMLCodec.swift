/// Implements the restricted XML interchange subset specified by XML/DESIGN.md.
/// Selected-target behavioral evidence is recorded in XML/DESIGN.md.
public struct BoundedXMLCodec: XMLDocumentCoding, Sendable {
    public init() {}
    public func decode(bytes: [UInt8], work: inout XMLWork) throws(XMLFailure) -> XMLDocument {
        try work.checkCancellation()
        guard bytes.count <= work.policy.maximumInputBytes else {
            throw XMLFailure(.limit(.inputBytes, work.policy.maximumInputBytes), at: XMLLocation())
        }
        var reader = XMLReader(bytes: bytes, work: work)
        defer { work = reader.cursor.work }
        return try reader.document()
    }
    public func encode(document: XMLDocument, work: inout XMLWork) throws(XMLFailure) -> [UInt8] {
        var writer = XMLWriter(work: work, measuring: true)
        defer { work = writer.work }
        try writer.document(document)
        let size = writer.size
        writer = XMLWriter(work: writer.work, measuring: false)
        try writer.work.allocate(size, at: XMLLocation())
        writer.bytes.reserveCapacity(size)
        try writer.document(document)
        guard writer.size == size else { throw XMLFailure(.invalidDocument, at: XMLLocation()) }
        try writer.work.checkCancellation()
        return writer.bytes
    }
}

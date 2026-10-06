public protocol XMLDocumentCoding: Sendable {
    func decode(bytes: [UInt8], work: inout XMLWork) throws(XMLFailure) -> XMLDocument
    func encode(document: XMLDocument, work: inout XMLWork) throws(XMLFailure) -> [UInt8]
}

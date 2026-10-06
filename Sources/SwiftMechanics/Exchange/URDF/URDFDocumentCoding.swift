public protocol URDFDocumentCoding: Sendable {
    func decode(bytes: [UInt8], options: URDFImportOptions, compilationPolicy: CompilationPolicy,
                work: inout URDFWork) throws(URDFFailure) -> URDFImportResult
    func encode(result: URDFImportResult, work: inout URDFWork) throws(URDFFailure) -> [UInt8]
}

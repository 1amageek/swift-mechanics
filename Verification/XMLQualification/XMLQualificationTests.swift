@testable import SwiftMechanics
// The isolated probe uses a support target; the canonical test target owns the same fixture files.
#if canImport(XMLQualificationSupport)
import XMLQualificationSupport
#endif
import Testing

@Suite struct XMLQualificationTests {
    @Test func originalMixedContentAndNormalization() throws { try XMLQualificationCases.decodeOriginal() }
    @Test func independentAuthoredWriterBytes() throws { try XMLQualificationCases.manualWriter() }
    @Test func scalarDeclarationAndLexicalNames() throws { try XMLQualificationCases.originalScalarAndDeclarationCases() }
    @Test func malformedUnsupportedAndDiagnostics() throws { try XMLQualificationCases.malformedAndUnsupported() }
    @Test func transactionalWriterRefusals() throws { try XMLQualificationCases.writerFailures() }
    @Test func budgetsAndExactLimits() throws { try XMLQualificationCases.budgetsAndLimits() }
    @Test func checkedArithmeticRejectsOverflow() throws {
        #expect(throws: XMLFailure(.arithmeticOverflow, at: XMLLocation())) {
            try XMLWork.increment(Int.max, 1, limit: Int.max, resource: .operations, at: XMLLocation())
        }
    }
    @Test func refusedOperationsRetainConsumedWork() throws {
        let codec: any XMLDocumentCoding = BoundedXMLCodec()
        var parseWork = XMLWork(policy: try XMLQualificationCases.policy(nodes: 0))
        #expect(throws: XMLFailure.self) {
            try codec.decode(bytes: Array("<a/>".utf8), work: &parseWork)
        }
        #expect(parseWork.operations > 0 && parseWork.decodedBytes > 0 && parseWork.storageBytes > 0)
        var writeWork = XMLWork(policy: try XMLQualificationCases.policy(output: 6))
        let document = XMLDocument(nodes: [XMLNode(parent: nil, content: .element(name: "a", attributes: []))], rootIndex: 0)
        #expect(throws: XMLFailure.self) { try codec.encode(document: document, work: &writeWork) }
        #expect(writeWork.operations > 0 && writeWork.decodedBytes > 0)
    }
    @Test(.timeLimit(.minutes(1))) func actualTaskCancellationHasNoPublication() async throws {
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try XMLQualificationCases.expectDecode(.cancelled, "<a/>")
            try XMLQualificationCases.expectEncode(.cancelled, document: XMLDocument(nodes: [XMLNode(parent: nil, content: .element(name: "a", attributes: []))], rootIndex: 0))
        }
        try await task.value
    }
}

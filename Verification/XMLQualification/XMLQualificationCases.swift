import SwiftMechanics

public enum XMLQualificationCases {
    public static func policy(input: Int = 1_048_576, output: Int = 1_048_576, nodes: Int = 4096,
                              attributes: Int = 4096, perElement: Int = 64, depth: Int = 128,
                              decoded: Int = 1_048_576, storage: Int = 4_194_304,
                              operations: Int = 10_000_000) throws -> XMLPolicy {
        try XMLPolicy(maximumInputBytes: input, maximumOutputBytes: output, maximumNodes: nodes,
                      maximumAttributes: attributes, maximumAttributesPerElement: perElement,
                      maximumDepth: depth, maximumDecodedBytes: decoded, maximumStorageBytes: storage,
                      maximumOperations: operations)
    }
    public static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw XMLQualificationError.assertion(message) }
    }
    public static func decodeOriginal() throws {
        let prefix = "\u{FEFF}<?xml version='1.0' encoding='uTf-8' standalone='yes'?>\r\n<!--before-->"
        let original = prefix + "<robot a='a\tb\r\nc&#xA;&#13;' b='&quot;&apos;&lt;&gt;&amp;'>lead<![CDATA[<&🛠]]><α/>tail&#x1F642;<!--end--></robot><!--after-->"
        let codec: any XMLDocumentCoding = BoundedXMLCodec()
        var work = XMLWork(policy: try policy())
        let document = try codec.decode(bytes: Array(original.utf8), work: &work)
        try check(document.rootIndex == 1 && document.nodes.count == 8 && document.declaration?.standalone == true, "Original root/declaration/node count")
        let root = document.nodes[1]
        try check(root.parent == nil && root.location.byteOffset == prefix.utf8.count && root.location.line == 2 && root.location.byteColumn == 14, "Original UTF8/CRLF root location")
        guard case .element(let name, let attributes) = root.content else { throw XMLQualificationError.assertion("Original element kind") }
        try check(name == "robot" && attributes.count == 2, "Original element/attributes")
        try check(attributes[0].name == "a" && attributes[0].value == "a b c\n\r" && attributes[1].value == "\"'<>&", "Original attribute normalization/predefined references")
        try comment(document.nodes[0], "before", parent: nil)
        try text(document.nodes[2], "lead", parent: 1)
        try text(document.nodes[3], "<&🛠", parent: 1)
        guard case .element(let child, let fields) = document.nodes[4].content else { throw XMLQualificationError.assertion("Original child") }
        try check(child == "α" && fields.isEmpty && document.nodes[4].parent == 1, "Original Unicode child")
        try text(document.nodes[5], "tail🙂", parent: 1)
        try comment(document.nodes[6], "end", parent: 1)
        try comment(document.nodes[7], "after", parent: nil)
        try check(work.operations > original.utf8.count && work.storageBytes > 0 && work.decodedBytes > 0, "Actual parser consumed work")
        let encoded = try codec.encode(document: document, work: &work)
        let expected = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><!--before--><robot a=\"a b c&#xA;&#xD;\" b=\"&quot;'&lt;&gt;&amp;\">lead&lt;&amp;🛠<α></α>tail🙂<!--end--></robot><!--after-->"
        try check(encoded.elementsEqual(expected.utf8), "Original parsed record writes independently expected bytes")
        let decoded = try codec.decode(bytes: encoded, work: &work)
        try check(decoded.rootIndex == 1 && decoded.nodes.count == 7, "Text segmentation is not XML semantics")
        try text(decoded.nodes[2], "lead<&🛠", parent: 1)
        try check(decoded.nodes[3].parent == 1 && decoded.nodes[4].parent == 1, "Writer output parent topology")
    }
    public static func manualWriter() throws {
        let document = XMLDocument(declaration: XMLDeclaration(standalone: false), nodes: [
            XMLNode(parent: nil, content: .comment("before")),
            XMLNode(parent: nil, content: .element(name: "root", attributes: [XMLAttribute(name: "x", value: "\t\n\r\"<&>日本")])),
            XMLNode(parent: 1, content: .text("x\r<&>🙂")),
            XMLNode(parent: 1, content: .element(name: "child", attributes: [])),
            XMLNode(parent: 3, content: .text("value")),
            XMLNode(parent: 1, content: .comment("inside")),
            XMLNode(parent: nil, content: .comment("after"))
        ], rootIndex: 1)
        let codec: any XMLDocumentCoding = BoundedXMLCodec()
        var work = XMLWork(policy: try policy())
        let bytes = try codec.encode(document: document, work: &work)
        let expected = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><!--before--><root x=\"&#x9;&#xA;&#xD;&quot;&lt;&amp;&gt;日本\">x&#xD;&lt;&amp;&gt;🙂<child>value</child><!--inside--></root><!--after-->"
        try check(bytes.elementsEqual(expected.utf8), "Manually authored writer has original escaping oracle")
        let result = try codec.decode(bytes: Array(expected.utf8), work: &work)
        try check(result.rootIndex == 1 && result.nodes.count == 7 && result.declaration?.standalone == false, "Independent expected wire decodes")
        try text(result.nodes[2], "x\r<&>🙂", parent: 1)
        try text(result.nodes[4], "value", parent: 3)
        guard case .element(_, let attributes) = result.nodes[1].content else { throw XMLQualificationError.assertion("Manual attributes") }
        try check(attributes[0].value == "\t\n\r\"<&>日本", "Referenced attribute whitespace is exact")
    }
    public static func originalScalarAndDeclarationCases() throws {
        let codec: any XMLDocumentCoding = BoundedXMLCodec()
        for declaration in ["", "<?xml version='1.0'?>", "<?xml version='1.0' standalone='no'?>"] {
            var work = XMLWork(policy: try policy())
            let document = try codec.decode(bytes: Array((declaration + "<a>é日本\r\nline\rnext&#65;&#x41;&#x10FFFF;</a>").utf8), work: &work)
            try text(document.nodes[1], "é日本\nline\nnextAA\u{10FFFF}", parent: 0)
            try check((document.declaration != nil) == !declaration.isEmpty, "Declaration presence")
        }
        var work = XMLWork(policy: try policy())
        let distinct = try codec.decode(bytes: Array("<a é='1' e\u{301}='2'/>".utf8), work: &work)
        guard case .element(_, let attributes) = distinct.nodes[0].content else { throw XMLQualificationError.assertion("Lexical attributes") }
        try check(attributes.count == 2, "Canonically equivalent names remain lexically distinct")
        try expectDecode(.mismatchedTag, "<é></e\u{301}>")
    }
    public static func malformedAndUnsupported() throws {
        let failures: [(XMLFailureReason, String)] = [
            (.missingRoot, ""), (.missingRoot, "<!--only-->"), (.multipleRoots, "<a/><b/>"),
            (.mismatchedTag, "<a></b>"), (.mismatchedTag, "</a>"), (.unexpectedEnd, "<a>"),
            (.unexpectedEnd, "<a x='no"), (.unexpectedEnd, "<!--unfinished"), (.unexpectedEnd, "<a><![CDATA[x"),
            (.duplicateAttribute, "<a x='1' x='2'/>"), (.invalidName, "<1/>"), (.malformedSyntax, "<a x='<'/>"),
            (.malformedSyntax, "<a x='1'y='2'/>"), (.malformedSyntax, "<a>]]></a>"),
            (.invalidComment, "<!--a--b--><a/>"), (.invalidComment, "<!--a---><a/>"),
            (.unsupportedDTD, "<!DOCTYPE a SYSTEM 'file:///never'><a/>"), (.unsupportedDTD, "<!DOCTYPE a [<!ENTITY e 'x'>]><a/>"),
            (.undeclaredEntity, "<a>&external;</a>"), (.unsupportedProcessingInstruction, "<?process a?><a/>"),
            (.unsupportedNamespaces, "<x:a/>"), (.unsupportedNamespaces, "<a xmlns='uri'/>"), (.unsupportedNamespaces, "<a xml:lang='en'/>"),
            (.unsupportedVersion, "<?xml version='1.1'?><a/>"), (.unsupportedEncoding, "<?xml version='1.0' encoding='UTF-16'?><a/>"),
            (.malformedSyntax, "<?xml standalone='yes' version='1.0'?><a/>"), (.malformedSyntax, "<?xml version='1.0' encoding='UTF-8' encoding='UTF-8'?><a/>"),
            (.invalidReference, "<a>&#0;</a>"), (.invalidReference, "<a>&#xD800;</a>"), (.invalidReference, "<a>&#x110000;</a>"),
            (.invalidReference, "<a>&#999999999999999999;</a>"), (.invalidReference, "<a>&#x;</a>"), (.invalidReference, "<a>&#z;</a>")
        ]
        for (reason, bytes) in failures { try expectDecode(reason, bytes) }
        for malformed: [UInt8] in [[0xc0, 0x80], [0x80], [0xed, 0xa0, 0x80], [0xf4, 0x90, 0x80, 0x80], [0xe2, 0x82]] {
            try expectDecode(.invalidUTF8, bytes: [60, 97, 62] + malformed + [60, 47, 97, 62])
        }
        try expectDecode(.invalidCharacter, bytes: [60, 97, 62, 0, 60, 47, 97, 62])
        try expectDecode(.unsupportedEncoding, bytes: [0xff, 0xfe, 60, 0, 97, 0])
        var work = XMLWork(policy: try policy())
        do throws(XMLFailure) { _ = try BoundedXMLCodec().decode(bytes: Array("<a>\r\n<z></x></a>".utf8), work: &work); throw XMLFailure(.invalidDocument, at: XMLLocation()) }
        catch { try check(error.reason == .mismatchedTag && error.location.byteOffset == 8 && error.location.line == 2 && error.location.byteColumn == 4, "Original mismatched line/byte diagnostics") }
    }
    public static func writerFailures() throws {
        let root = XMLNode(parent: nil, content: .element(name: "a", attributes: []))
        let failures: [(XMLFailureReason, XMLDocument)] = [
            (.invalidDocument, XMLDocument(nodes: [], rootIndex: 0)),
            (.invalidDocument, XMLDocument(nodes: [root], rootIndex: Int.max)),
            (.invalidDocument, XMLDocument(nodes: [root, root], rootIndex: 0)),
            (.invalidDocument, XMLDocument(nodes: [root, XMLNode(parent: 1, content: .text("cycle"))], rootIndex: 0)),
            (.invalidDocument, XMLDocument(nodes: [root, XMLNode(parent: nil, content: .text("outside"))], rootIndex: 0)),
            (.invalidDocument, XMLDocument(nodes: [root, XMLNode(parent: nil, content: .comment("closed")), XMLNode(parent: 0, content: .text("reopen"))], rootIndex: 0)),
            (.duplicateAttribute, XMLDocument(nodes: [XMLNode(parent: nil, content: .element(name: "a", attributes: [XMLAttribute(name: "x", value: "1"), XMLAttribute(name: "x", value: "2")]))], rootIndex: 0)),
            (.invalidName, XMLDocument(nodes: [XMLNode(parent: nil, content: .element(name: "1", attributes: []))], rootIndex: 0)),
            (.unsupportedNamespaces, XMLDocument(nodes: [XMLNode(parent: nil, content: .element(name: "p:a", attributes: []))], rootIndex: 0)),
            (.invalidCharacter, XMLDocument(nodes: [root, XMLNode(parent: 0, content: .text("\u{0}"))], rootIndex: 0)),
            (.invalidComment, XMLDocument(nodes: [root, XMLNode(parent: 0, content: .comment("x--y"))], rootIndex: 0)),
            (.invalidComment, XMLDocument(nodes: [root, XMLNode(parent: 0, content: .comment("x-"))], rootIndex: 0)),
            (.invalidComment, XMLDocument(nodes: [root, XMLNode(parent: 0, content: .comment("x\r"))], rootIndex: 0))
        ]
        for (reason, document) in failures { try expectEncode(reason, document: document) }
    }
    public static func budgetsAndLimits() throws {
        let failures: [(XMLResource, Int, XMLPolicy, String)] = try [
            (.inputBytes, 3, policy(input: 3), "<a/>"), (.nodes, 0, policy(nodes: 0), "<a/>"),
            (.attributes, 0, policy(attributes: 0), "<a x='1'/>"), (.attributesPerElement, 0, policy(perElement: 0), "<a x='1'/>"),
            (.depth, 1, policy(depth: 1), "<a><b/></a>"), (.decodedBytes, 0, policy(decoded: 0), "<a/>"),
            (.storageBytes, 0, policy(storage: 0), "<a/>"), (.operations, 0, policy(operations: 0), "<a/>")
        ]
        for (resource, limit, policy, input) in failures { try expectDecode(.limit(resource, limit), bytes: Array(input.utf8), policy: policy) }
        let document = XMLDocument(nodes: [XMLNode(parent: nil, content: .element(name: "a", attributes: []))], rootIndex: 0)
        try expectEncode(.limit(.outputBytes, 6), document: document, policy: policy(output: 6))
        try expectEncode(.limit(.depth, 0), document: document, policy: policy(depth: 0))
        try expectEncode(.limit(.storageBytes, 0), document: document, policy: policy(storage: 0))
        var work = XMLWork(policy: try policy(input: 4, output: 7, nodes: 1, depth: 1))
        let accepted = try BoundedXMLCodec().decode(bytes: Array("<a/>".utf8), work: &work)
        let output = try BoundedXMLCodec().encode(document: accepted, work: &work)
        try check(output.elementsEqual("<a></a>".utf8), "Exact input/output/depth/node limits")
        do { _ = try policy(depth: -1); throw XMLQualificationError.assertion("Negative policy accepted") }
        catch let failure as XMLFailure { try check(failure.reason == .invalidPolicy, "Negative policy reason") }
        var unlimited = XMLWork(policy: try policy(input: Int.max, output: Int.max, nodes: Int.max, attributes: Int.max, perElement: Int.max, depth: Int.max, decoded: Int.max, storage: Int.max, operations: Int.max))
        _ = try BoundedXMLCodec().decode(bytes: Array("<a/>".utf8), work: &unlimited)
        try check(unlimited.operations > 0, "Representable maximal policy still executes")
    }
    public static func expectDecode(_ reason: XMLFailureReason, _ text: String) throws { try expectDecode(reason, bytes: Array(text.utf8)) }
    public static func expectDecode(_ reason: XMLFailureReason, bytes: [UInt8], policy: XMLPolicy? = nil) throws {
        var work = XMLWork(policy: try policy ?? self.policy())
        let codec: any XMLDocumentCoding = BoundedXMLCodec()
        do throws(XMLFailure) { _ = try codec.decode(bytes: bytes, work: &work) }
        catch { try check(error.reason == reason, "Unexpected decode failure reason"); return }
        throw XMLQualificationError.assertion("Malformed input produced successful document")
    }
    public static func expectEncode(_ reason: XMLFailureReason, document: XMLDocument, policy: XMLPolicy? = nil) throws {
        var work = XMLWork(policy: try policy ?? self.policy())
        let codec: any XMLDocumentCoding = BoundedXMLCodec()
        do throws(XMLFailure) { _ = try codec.encode(document: document, work: &work) }
        catch { try check(error.reason == reason, "Unexpected encode failure reason"); return }
        throw XMLQualificationError.assertion("Invalid document produced successful bytes")
    }
    static func text(_ node: XMLNode, _ expected: String, parent: Int) throws {
        guard case .text(let value) = node.content else { throw XMLQualificationError.assertion("Text node kind") }
        try check(value.utf8.elementsEqual(expected.utf8) && node.parent == parent, "Original text/scalar and parent oracle")
    }
    static func comment(_ node: XMLNode, _ expected: String, parent: Int?) throws {
        guard case .comment(let value) = node.content else { throw XMLQualificationError.assertion("Comment node kind") }
        try check(value == expected && node.parent == parent, "Original comment and parent oracle")
    }
}

internal struct XMLReader {
    var cursor: XMLCursor
    var nodes: [XMLNode] = []
    var stack: [Int] = []
    var attributes = 0
    init(bytes: [UInt8], work: XMLWork) { cursor = XMLCursor(bytes: bytes, work: work) }

    mutating func document() throws(XMLFailure) -> XMLDocument {
        if cursor.bytes.count >= 2 && ((cursor.bytes[0] == 0xff && cursor.bytes[1] == 0xfe) || (cursor.bytes[0] == 0xfe && cursor.bytes[1] == 0xff)) {
            throw XMLFailure(.unsupportedEncoding, at: cursor.location)
        }
        if cursor.bytes.count >= 4 {
            let prefix = cursor.bytes[0..<4]
            if prefix.elementsEqual([0, 0, 0xfe, 0xff]) || prefix.elementsEqual([0, 0, 0, 60])
                || prefix.elementsEqual([60, 0, 0, 0]) || prefix.elementsEqual([0, 60, 0, 63])
                || prefix.elementsEqual([60, 0, 63, 0]) {
                throw XMLFailure(.unsupportedEncoding, at: cursor.location)
            }
        }
        // Validate strict encoding/characters before interpreting any markup.
        while !cursor.ended { _ = try cursor.takeScalar() }
        cursor.offset = 0; cursor.line = 1; cursor.column = 1; cursor.previousCR = false
        if cursor.starts("\u{feff}") { _ = try cursor.takeScalar() }
        var declaration: XMLDeclaration?
        if cursor.starts("<?xml") { declaration = try readDeclaration() }
        var root: Int?
        while !cursor.ended {
            let location = cursor.location
            if cursor.starts("<!--") {
                try cursor.expect("<!--")
                var value = ""
                while !cursor.starts("-->") {
                    if cursor.starts("--") { throw XMLFailure(.invalidComment, at: cursor.location) }
                    try appendNormalized(to: &value)
                }
                try cursor.expect("-->")
                try node(.comment(value), parent: stack.last, at: location)
            } else if cursor.starts("<![CDATA[") {
                guard let parent = stack.last else { throw XMLFailure(.malformedSyntax, at: location) }
                try cursor.expect("<![CDATA[")
                var value = ""
                while !cursor.starts("]]>") { try appendNormalized(to: &value) }
                try cursor.expect("]]>")
                try node(.text(value), parent: parent, at: location)
            } else if cursor.starts("<!DOCTYPE") {
                throw XMLFailure(.unsupportedDTD, at: location)
            } else if cursor.starts("<?") {
                throw XMLFailure(.unsupportedProcessingInstruction, at: location)
            } else if cursor.starts("<!") {
                throw XMLFailure(.unsupportedDeclaration, at: location)
            } else if cursor.starts("</") {
                try cursor.expect("</")
                let name = try readName()
                _ = try cursor.whitespace(); try cursor.expect(">")
                guard let parent = stack.last, case .element(let opening, _) = nodes[parent].content else {
                    throw XMLFailure(.mismatchedTag, at: location)
                }
                guard try XMLGrammar.same(name, opening, work: &cursor.work, at: location) else { throw XMLFailure(.mismatchedTag, at: location) }
                stack.removeLast()
            } else if cursor.starts("<") {
                try cursor.expect("<")
                let name = try readName()
                var fields: [XMLAttribute] = []
                while true {
                    let separated = try cursor.whitespace()
                    if cursor.starts(">") || cursor.starts("/>") { break }
                    guard separated else { throw XMLFailure(.malformedSyntax, at: cursor.location) }
                    let position = cursor.location
                    let attribute = try readName()
                    if attribute == "xmlns" { throw XMLFailure(.unsupportedNamespaces, at: position) }
                    for previous in fields {
                        guard try !XMLGrammar.same(attribute, previous.name, work: &cursor.work, at: position) else {
                            throw XMLFailure(.duplicateAttribute, at: position)
                        }
                    }
                    attributes = try XMLWork.increment(attributes, 1, limit: cursor.work.policy.maximumAttributes, resource: .attributes, at: position)
                    _ = try XMLWork.increment(fields.count, 1, limit: cursor.work.policy.maximumAttributesPerElement, resource: .attributesPerElement, at: position)
                    try cursor.work.allocate(MemoryLayout<XMLAttribute>.stride, at: position)
                    _ = try cursor.whitespace(); try cursor.expect("="); _ = try cursor.whitespace()
                    let value = try quoted(references: true)
                    fields.append(XMLAttribute(name: attribute, value: value, location: position))
                }
                let index = nodes.count
                if stack.isEmpty {
                    guard root == nil else { throw XMLFailure(.multipleRoots, at: location) }
                    root = index
                }
                _ = try XMLWork.increment(stack.count, 1, limit: cursor.work.policy.maximumDepth, resource: .depth, at: location)
                try node(.element(name: name, attributes: fields), parent: stack.last, at: location)
                if cursor.starts("/>") { try cursor.expect("/>") }
                else {
                    try cursor.expect(">")
                    try cursor.work.allocate(MemoryLayout<Int>.stride, at: location)
                    stack.append(index)
                }
            } else if stack.isEmpty {
                guard try cursor.whitespace() else { throw XMLFailure(.malformedSyntax, at: location) }
            } else {
                var value = ""
                while !cursor.ended && !cursor.starts("<") {
                    if cursor.starts("]]>") { throw XMLFailure(.malformedSyntax, at: cursor.location) }
                    if cursor.starts("&") { let scalar = try reference(); try cursor.append(scalar, to: &value) }
                    else { try appendNormalized(to: &value) }
                }
                try node(.text(value), parent: stack.last, at: location)
            }
        }
        guard stack.isEmpty else { throw XMLFailure(.unexpectedEnd, at: cursor.location) }
        guard let root else { throw XMLFailure(.missingRoot, at: cursor.location) }
        try cursor.work.checkCancellation(at: cursor.location)
        return XMLDocument(declaration: declaration, nodes: nodes, rootIndex: root)
    }
    mutating func node(_ content: XMLNodeContent, parent: Int?, at location: XMLLocation) throws(XMLFailure) {
        _ = try XMLWork.increment(nodes.count, 1, limit: cursor.work.policy.maximumNodes, resource: .nodes, at: location)
        try cursor.work.allocate(MemoryLayout<XMLNode>.stride, at: location)
        nodes.append(XMLNode(parent: parent, content: content, location: location))
    }
    mutating func appendNormalized(to value: inout String) throws(XMLFailure) {
        let scalar = try cursor.takeScalar(normalize: true)
        try cursor.append(scalar, to: &value)
    }
    mutating func readName() throws(XMLFailure) -> String {
        var result = "", first = true
        while !cursor.ended {
            let scalar = try cursor.scalar().0
            if scalar == 58 { throw XMLFailure(.unsupportedNamespaces, at: cursor.location) }
            if !(first ? XMLGrammar.nameStart(scalar) : XMLGrammar.nameContinuation(scalar)) { break }
            _ = try cursor.takeScalar(); try cursor.append(scalar, to: &result); first = false
        }
        guard !first else { throw XMLFailure(.invalidName, at: cursor.location) }
        return result
    }
    mutating func quoted(references: Bool) throws(XMLFailure) -> String {
        let quote = try cursor.scalar().0
        guard quote == 34 || quote == 39 else { throw XMLFailure(.malformedSyntax, at: cursor.location) }
        _ = try cursor.takeScalar()
        var result = ""
        while try cursor.scalar().0 != quote {
            if cursor.starts("<") { throw XMLFailure(.malformedSyntax, at: cursor.location) }
            if cursor.starts("&") {
                guard references else { throw XMLFailure(.malformedSyntax, at: cursor.location) }
                let value = try reference(); try cursor.append(value, to: &result)
            } else {
                var value = try cursor.takeScalar(normalize: true)
                if XMLGrammar.whitespace(value) { value = 32 }
                try cursor.append(value, to: &result)
            }
        }
        _ = try cursor.takeScalar()
        return result
    }
    mutating func reference() throws(XMLFailure) -> UInt32 {
        let location = cursor.location
        try cursor.expect("&")
        if cursor.starts("#") {
            try cursor.expect("#")
            var base: UInt32 = 10
            if cursor.starts("x") { try cursor.expect("x"); base = 16 }
            var value: UInt32 = 0, count = 0
            while !cursor.ended && !cursor.starts(";") {
                let byte = cursor.bytes[cursor.offset]
                let digit: UInt32
                switch byte {
                case 48...57: digit = UInt32(byte - 48)
                case 65...70 where base == 16: digit = UInt32(byte - 55)
                case 97...102 where base == 16: digit = UInt32(byte - 87)
                default: throw XMLFailure(.invalidReference, at: cursor.location)
                }
                let (multiplied, overflow1) = value.multipliedReportingOverflow(by: base)
                let (next, overflow2) = multiplied.addingReportingOverflow(digit)
                guard !overflow1, !overflow2, next <= 0x10ffff else { throw XMLFailure(.invalidReference, at: location) }
                value = next; count += 1; try cursor.advanceByte()
            }
            guard count > 0, XMLGrammar.character(value) else { throw XMLFailure(.invalidReference, at: location) }
            try cursor.expect(";"); return value
        }
        for (name, scalar): (String, UInt32) in [("lt;", 60), ("gt;", 62), ("amp;", 38), ("apos;", 39), ("quot;", 34)] {
            if cursor.starts(name) { try cursor.expect(name); return scalar }
        }
        throw XMLFailure(.undeclaredEntity, at: location)
    }
    mutating func readDeclaration() throws(XMLFailure) -> XMLDeclaration {
        try cursor.expect("<?xml")
        guard try cursor.whitespace() else { throw XMLFailure(.malformedSyntax, at: cursor.location) }
        let version = try pseudoAttribute(expected: "version")
        guard version == "1.0" else { throw XMLFailure(.unsupportedVersion, at: cursor.location) }
        var standalone: Bool?
        var separation = try cursor.whitespace()
        if cursor.starts("encoding") {
            guard separation else { throw XMLFailure(.malformedSyntax, at: cursor.location) }
            let encoding = try pseudoAttribute(expected: "encoding")
            guard encoding.utf8.count == 5 else { throw XMLFailure(.unsupportedEncoding, at: cursor.location) }
            // Case folding is ASCII-only; no Unicode repair or alternative codec.
            var expected = "utf-8".utf8.makeIterator()
            for byte in encoding.utf8 {
                let lower = byte >= 65 && byte <= 90 ? byte + 32 : byte
                guard lower == expected.next() else { throw XMLFailure(.unsupportedEncoding, at: cursor.location) }
            }
            separation = try cursor.whitespace()
        }
        if cursor.starts("standalone") {
            guard separation else { throw XMLFailure(.malformedSyntax, at: cursor.location) }
            let value = try pseudoAttribute(expected: "standalone")
            if value == "yes" { standalone = true }
            else if value == "no" { standalone = false }
            else { throw XMLFailure(.malformedSyntax, at: cursor.location) }
            _ = try cursor.whitespace()
        }
        try cursor.expect("?>")
        return XMLDeclaration(standalone: standalone)
    }
    mutating func pseudoAttribute(expected: String) throws(XMLFailure) -> String {
        try cursor.expect(expected); _ = try cursor.whitespace(); try cursor.expect("="); _ = try cursor.whitespace()
        return try quoted(references: false)
    }
}

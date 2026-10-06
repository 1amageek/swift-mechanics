internal struct XMLWriter {
    var work: XMLWork
    let measuring: Bool
    var bytes: [UInt8] = []
    var size = 0
    var attributes = 0
    var stack: [Int] = []

    mutating func document(_ document: XMLDocument) throws(XMLFailure) {
        try work.checkCancellation()
        guard document.nodes.count <= work.policy.maximumNodes else { throw XMLFailure(.limit(.nodes, work.policy.maximumNodes), at: XMLLocation()) }
        guard document.rootIndex >= 0, document.rootIndex < document.nodes.count else { throw XMLFailure(.invalidDocument, at: XMLLocation()) }
        if let declaration = document.declaration {
            try emit("<?xml version=\"1.0\" encoding=\"UTF-8\"", at: XMLLocation())
            if let standalone = declaration.standalone { try emit(standalone ? " standalone=\"yes\"" : " standalone=\"no\"", at: XMLLocation()) }
            try emit("?>", at: XMLLocation())
        }
        var root: Int?
        for index in document.nodes.indices {
            let node = document.nodes[index], location = node.location
            try work.charge(1, at: location)
            if let parent = node.parent {
                guard parent >= 0, parent < index else { throw XMLFailure(.invalidDocument, at: location) }
            }
            while stack.last != node.parent {
                guard let closed = stack.popLast(), case .element(let name, _) = document.nodes[closed].content else {
                    throw XMLFailure(.invalidDocument, at: location)
                }
                try emit("</", at: location); try emit(name, at: location); try emit(">", at: location)
            }
            switch node.content {
            case .element(let name, let fields):
                if node.parent == nil {
                    guard root == nil, index == document.rootIndex else { throw XMLFailure(.invalidDocument, at: location) }
                    root = index
                }
                try XMLGrammar.validateName(name, work: &work, at: location)
                try payload(name, at: location)
                _ = try XMLWork.increment(stack.count, 1, limit: work.policy.maximumDepth, resource: .depth, at: location)
                guard fields.count <= work.policy.maximumAttributesPerElement else { throw XMLFailure(.limit(.attributesPerElement, work.policy.maximumAttributesPerElement), at: location) }
                attributes = try XMLWork.increment(attributes, fields.count, limit: work.policy.maximumAttributes, resource: .attributes, at: location)
                try emit("<", at: location); try emit(name, at: location)
                for fieldIndex in fields.indices {
                    let field = fields[fieldIndex]
                    try XMLGrammar.validateName(field.name, work: &work, at: field.location)
                    if field.name == "xmlns" { throw XMLFailure(.unsupportedNamespaces, at: field.location) }
                    for previous in 0..<fieldIndex {
                        guard try !XMLGrammar.same(field.name, fields[previous].name, work: &work, at: field.location) else {
                            throw XMLFailure(.duplicateAttribute, at: field.location)
                        }
                    }
                    try payload(field.name, at: field.location); try payload(field.value, at: field.location)
                    try emit(" ", at: field.location); try emit(field.name, at: field.location); try emit("=\"", at: field.location)
                    try escaped(field.value, attribute: true, at: field.location); try emit("\"", at: field.location)
                }
                try emit(">", at: location)
                try work.allocate(MemoryLayout<Int>.stride, at: location); stack.append(index)
            case .text(let value):
                guard node.parent != nil else { throw XMLFailure(.invalidDocument, at: location) }
                try payload(value, at: location); try escaped(value, attribute: false, at: location)
            case .comment(let value):
                try payload(value, at: location)
                var previousHyphen = false
                for scalar in value.unicodeScalars {
                    try work.charge(1, at: location)
                    guard XMLGrammar.character(scalar.value), scalar.value != 13 else { throw XMLFailure(.invalidComment, at: location) }
                    if scalar.value == 45 && previousHyphen { throw XMLFailure(.invalidComment, at: location) }
                    previousHyphen = scalar.value == 45
                }
                guard !previousHyphen else { throw XMLFailure(.invalidComment, at: location) }
                try emit("<!--", at: location); try emit(value, at: location); try emit("-->", at: location)
            }
        }
        while let closed = stack.popLast() {
            guard case .element(let name, _) = document.nodes[closed].content else { throw XMLFailure(.invalidDocument, at: XMLLocation()) }
            try emit("</", at: document.nodes[closed].location); try emit(name, at: document.nodes[closed].location); try emit(">", at: document.nodes[closed].location)
        }
        guard root == document.rootIndex else { throw XMLFailure(.invalidDocument, at: XMLLocation()) }
        try work.checkCancellation()
    }
    mutating func payload(_ text: String, at location: XMLLocation) throws(XMLFailure) {
        // Caller-owned input is inspected, not copied into writer-owned storage.
        for _ in text.utf8 {
            try work.charge(1, at: location)
            if measuring { try work.inspectPayload(1, at: location) }
        }
    }
    mutating func emit(_ text: String, at location: XMLLocation) throws(XMLFailure) {
        for byte in text.utf8 {
            try work.charge(1, at: location)
            size = try XMLWork.increment(size, 1, limit: work.policy.maximumOutputBytes, resource: .outputBytes, at: location)
            if !measuring { bytes.append(byte) }
        }
    }
    mutating func escaped(_ value: String, attribute: Bool, at location: XMLLocation) throws(XMLFailure) {
        for scalar in value.unicodeScalars {
            try work.charge(1, at: location)
            guard XMLGrammar.character(scalar.value) else { throw XMLFailure(.invalidCharacter, at: location) }
            switch scalar.value {
            case 38: try emit("&amp;", at: location)
            case 60: try emit("&lt;", at: location)
            case 62: try emit("&gt;", at: location)
            case 34 where attribute: try emit("&quot;", at: location)
            case 9 where attribute: try emit("&#x9;", at: location)
            case 10 where attribute: try emit("&#xA;", at: location)
            case 13: try emit("&#xD;", at: location)
            default:
                // Encode scalars directly; no per-scalar intermediate String/Array.
                let code = scalar.value
                if code < 0x80 { try emitByte(UInt8(code), at: location) }
                else if code < 0x800 {
                    try emitByte(UInt8(0xc0 | (code >> 6)), at: location)
                    try emitByte(UInt8(0x80 | (code & 63)), at: location)
                } else if code < 0x10000 {
                    try emitByte(UInt8(0xe0 | (code >> 12)), at: location)
                    try emitByte(UInt8(0x80 | ((code >> 6) & 63)), at: location)
                    try emitByte(UInt8(0x80 | (code & 63)), at: location)
                } else {
                    try emitByte(UInt8(0xf0 | (code >> 18)), at: location)
                    try emitByte(UInt8(0x80 | ((code >> 12) & 63)), at: location)
                    try emitByte(UInt8(0x80 | ((code >> 6) & 63)), at: location)
                    try emitByte(UInt8(0x80 | (code & 63)), at: location)
                }
            }
        }
    }
    mutating func emitByte(_ byte: UInt8, at location: XMLLocation) throws(XMLFailure) {
        try work.charge(1, at: location)
        size = try XMLWork.increment(size, 1, limit: work.policy.maximumOutputBytes, resource: .outputBytes, at: location)
        if !measuring { bytes.append(byte) }
    }
}

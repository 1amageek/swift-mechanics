internal struct MJCFElementTable {
    let document: XMLDocument
    let children: [[Int]]
    init(_ document: XMLDocument, work: inout MJCFWork) throws(MJCFError) {
        self.document = document
        try work.allocate(try MJCFArithmetic.product(document.nodes.count, MemoryLayout<[Int]>.stride))
        var children = [[Int]](repeating: [], count: document.nodes.count), attributes = 0
        for index in document.nodes.indices {
            try work.charge(1)
            let node = document.nodes[index]
            switch node.content {
            case .element(let name, let fields):
                try work.text(name)
                attributes = try MJCFArithmetic.sum(attributes, fields.count)
                guard attributes <= work.policy.maximumAttributes else { throw .capacityExceeded }
                for field in fields { try work.text(field.name); try work.text(field.value) }
                if let parent = node.parent {
                    guard parent >= 0, parent < index, case .element = document.nodes[parent].content else { throw .invalidInput(node: index, field: "parent") }
                    try work.allocate(MemoryLayout<Int>.stride); children[parent].append(index)
                }
            case .text(let text):
                for byte in text.utf8 { try work.charge(1); guard byte == 32 || byte == 9 || byte == 10 || byte == 13 else { throw .invalidInput(node: index, field: "text") } }
            case .comment: break
            }
        }
        guard document.rootIndex >= 0, document.rootIndex < document.nodes.count else { throw .invalidInput(node: -1, field: "root") }
        self.children = children
    }
    func name(_ node: Int) -> String { if case .element(let name, _) = document.nodes[node].content { return name }; return "" }
    func fields(_ node: Int, work: inout MJCFWork) throws(MJCFError) -> [MJCFEffectiveAttribute] {
        guard case .element(_, let fields) = document.nodes[node].content else { throw .invalidInput(node: node, field: "element") }
        try work.allocate(try MJCFArithmetic.product(fields.count, MemoryLayout<MJCFEffectiveAttribute>.stride))
        var result: [MJCFEffectiveAttribute] = []
        for field in fields { try work.charge(1); result.append(MJCFEffectiveAttribute(name: field.name, value: field.value, definingNode: node, inherited: false)) }
        return result
    }
    static func value(_ fields: [MJCFEffectiveAttribute], _ name: String, work: inout MJCFWork) throws(MJCFError) -> String? {
        for field in fields { try work.charge(1); if field.name == name { return field.value } }; return nil
    }
    static func required(_ fields: [MJCFEffectiveAttribute], _ name: String, node: Int, work: inout MJCFWork) throws(MJCFError) -> String {
        guard let value = try value(fields, name, work: &work), !value.isEmpty else { throw .missingField(node: node, field: name) }; return value
    }
    static func check(_ fields: [MJCFEffectiveAttribute], allowed: [String], node: Int, work: inout MJCFWork) throws(MJCFError) {
        for field in fields {
            var found = false
            for name in allowed { try work.charge(1); if field.name == name { found = true } }
            // FIXME(INCOMPLETE_IMPLEMENTATION): importModel reaches unsupported schema fields here.
            // Additional MJCF semantics require their real provider and original behavioral proof before admission.
            guard found else { throw .unsupported(node: node, feature: field.name) }
        }
    }
    static func numbers(_ fields: [MJCFEffectiveAttribute], _ name: String, fallback: [Double]?, count: Int, node: Int, work: inout MJCFWork) throws(MJCFError) -> [Double] {
        if let value = try value(fields, name, work: &work) {
            let numbers = try MJCFArithmetic.numbers(value, maximum: count, node: node, work: &work)
            guard numbers.count == count else { throw .invalidInput(node: node, field: name) }; return numbers
        }
        guard let fallback else { throw .missingField(node: node, field: name) }; return fallback
    }
    func pose(_ fields: [MJCFEffectiveAttribute], node: Int, work: inout MJCFWork) throws(MJCFError) -> RigidTransform {
        let p = try Self.numbers(fields, "pos", fallback: [0,0,0], count: 3, node: node, work: &work)
        let q = try Self.numbers(fields, "quat", fallback: [1,0,0,0], count: 4, node: node, work: &work)
        return try MJCFArithmetic.core { () throws(CoreError) in
            RigidTransform(rotation: try UnitQuaternion(w: q[0], x: q[1], y: q[2], z: q[3]), translation: try Vector3(p[0], p[1], p[2]))
        }
    }
}

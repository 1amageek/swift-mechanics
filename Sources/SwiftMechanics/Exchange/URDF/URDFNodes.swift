internal struct URDFNodes {
    let document: XMLDocument
    let children: [[Int]]
    init(_ document: XMLDocument, work: inout URDFWork) throws(URDFFailure) {
        guard document.nodes.indices.contains(document.rootIndex) else { throw URDFFailure(.invalid("XML root")) }
        try work.allocate(document.nodes.count, stride: MemoryLayout<[Int]>.stride)
        try work.allocate(document.nodes.count, stride: MemoryLayout<Int>.stride)
        var children = [[Int]](repeating: [], count: document.nodes.count)
        for index in document.nodes.indices {
            let node = document.nodes[index]; try work.charge(1, at: node.location)
            if let parent = node.parent {
                guard parent >= 0, parent < index, case .element = document.nodes[parent].content else {
                    throw URDFFailure(.invalid("XML parent"), at: node.location)
                }
                children[parent].append(index)
            }
        }
        self.document = document; self.children = children
    }
    func location(_ index: Int) -> XMLLocation { document.nodes[index].location }
    func name(_ index: Int) -> String {
        if case .element(let name, _) = document.nodes[index].content { return name }
        return ""
    }
    func attribute(_ index: Int, _ key: String, required: Bool = false, work: inout URDFWork) throws(URDFFailure) -> String? {
        guard case .element(_, let attributes) = document.nodes[index].content else {
            throw URDFFailure(.invalid("element"), at: location(index))
        }
        for attribute in attributes {
            try work.charge(1, at: attribute.location)
            if attribute.name == key { return attribute.value }
        }
        if required { throw URDFFailure(.missing(key), at: location(index)) }
        return nil
    }
    func elements(_ index: Int, work: inout URDFWork) throws(URDFFailure) -> [Int] {
        try work.allocate(children[index].count, stride: MemoryLayout<Int>.stride, at: location(index))
        var result: [Int] = []; result.reserveCapacity(children[index].count)
        for child in children[index] {
            try work.charge(1, at: location(child))
            switch document.nodes[child].content {
            case .element: result.append(child)
            case .comment: break
            case .text(let text):
                try work.charge(text.utf8.count, at: location(child))
                guard text.utf8.allSatisfy({ $0 == 32 || $0 == 9 || $0 == 10 || $0 == 13 }) else {
                    throw URDFFailure(.invalid("unexpected text"), at: location(child))
                }
            }
        }
        return result
    }
    func single(_ index: Int, _ key: String, required: Bool = false, work: inout URDFWork) throws(URDFFailure) -> Int? {
        var found: Int? = nil
        for child in children[index] {
            try work.charge(1, at: location(child))
            if name(child) == key {
                guard found == nil else { throw URDFFailure(.duplicate(key), at: location(child)) }
                found = child
            }
        }
        if required, found == nil { throw URDFFailure(.missing(key), at: location(index)) }
        return found
    }
}

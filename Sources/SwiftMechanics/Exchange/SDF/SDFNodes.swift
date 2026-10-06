internal struct SDFNodes {
    let document: XMLDocument
    let children: [[Int]]
    init(_ document: XMLDocument, work: inout SDFWork) throws(SDFError) {
        let slots: Int
        do throws(NumericalError) {
            let perNode = try NumericalWork.sum(192, NumericalWork.product(work.policy.maximumTokenBytes, 16))
            slots = try NumericalWork.sum(NumericalWork.product(document.nodes.count, perNode),
                NumericalWork.product(work.policy.xml.maximumDecodedBytes, 2))
        } catch { throw .numerical(error) }
        try work.reserve(slots)
        var children = [[Int]](repeating: [], count: document.nodes.count)
        for (index, value) in document.nodes.enumerated() {
            try work.charge(4)
            if let parent = value.parent {
                guard parent >= 0, parent < index else { throw .invalidInput(node: index) }
                children[parent].append(index)
            }
        }
        self.document = document; self.children = children
    }
    func name(_ node: Int) -> String {
        if case .element(let name, _) = document.nodes[node].content { return name }
        return ""
    }
    func elements(_ node: Int, work: inout SDFWork) throws(SDFError) -> [Int] {
        var result: [Int] = []
        for child in children[node] {
            try work.charge(2)
            if case .element = document.nodes[child].content { result.append(child) }
            else if case .text(let text) = document.nodes[child].content {
                try work.inspect(text)
                guard text.allSatisfy({ $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "\r" }) else { throw .invalidInput(node: child) }
            }
        }
        return result
    }
    func attribute(_ node: Int, _ name: String, work: inout SDFWork) throws(SDFError) -> String? {
        guard case .element(_, let attributes) = document.nodes[node].content else { throw .invalidInput(node: node) }
        for attribute in attributes {
            try work.inspect(attribute.name)
            if attribute.name == name { try work.inspect(attribute.value); return attribute.value }
        }
        return nil
    }
    func checked(_ node: Int, attributes allowed: [String], work: inout SDFWork) throws(SDFError) {
        guard case .element(_, let attributes) = document.nodes[node].content else { throw .invalidInput(node: node) }
        for attribute in attributes {
            try work.inspect(attribute.name)
            guard allowed.contains(attribute.name) else { throw .unsupported(element: attribute.name, node: node) }
        }
    }
    func single(_ node: Int, _ name: String, required: Bool = false, work: inout SDFWork) throws(SDFError) -> Int? {
        var result: Int?
        for child in try elements(node, work: &work) where self.name(child) == name {
            guard result == nil else { throw .invalidInput(node: node) }; result = child
        }
        if required, result == nil { throw .missing(element: name, node: node) }
        return result
    }
    func text(_ node: Int, work: inout SDFWork) throws(SDFError) -> String {
        var result = ""
        for child in children[node] {
            try work.charge(2)
            if case .text(let value) = document.nodes[child].content {
                try work.inspect(value); try work.inspect(result); result += value
            } else if case .element = document.nodes[child].content { throw .invalidInput(node: node) }
        }
        return result
    }
}

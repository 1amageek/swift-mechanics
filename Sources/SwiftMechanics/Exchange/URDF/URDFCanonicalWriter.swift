internal struct URDFCanonicalWriter {
    func document(_ source: XMLDocument, work: inout URDFWork) throws(URDFFailure) -> XMLDocument {
        try work.allocate(source.nodes.count, stride: MemoryLayout<Int?>.stride)
        try work.allocate(source.nodes.count, stride: MemoryLayout<XMLNode>.stride)
        var remap = [Int?](repeating: nil, count: source.nodes.count)
        var output: [XMLNode] = []; output.reserveCapacity(source.nodes.count)
        for index in source.nodes.indices {
            let node = source.nodes[index]; try work.charge(1, at: node.location)
            if case .comment = node.content { continue }
            let parent: Int?
            if let old = node.parent {
                guard old >= 0, old < index, let mapped = remap[old] else {
                    throw URDFFailure(.invalid("export parent"), at: node.location)
                }
                parent = mapped
            } else { parent = nil }
            let content: XMLNodeContent
            switch node.content {
            case .element(let name, let original):
                try work.allocate(original.count, stride: MemoryLayout<XMLAttribute>.stride, at: node.location)
                var attributes = original
                // Stable insertion sort has a caller-charged comparison path and no hidden callback work.
                for position in attributes.indices.dropFirst() {
                    var current = position
                    while current > 0 {
                        let left = attributes[current - 1].name, right = attributes[current].name
                        try work.charge(left.utf8.count, at: node.location)
                        try work.charge(right.utf8.count, at: node.location)
                        if !right.utf8.lexicographicallyPrecedes(left.utf8) { break }
                        attributes.swapAt(current - 1, current); current -= 1
                    }
                }
                content = .element(name: name, attributes: attributes)
            case .text(let text): content = .text(text)
            case .comment: continue
            }
            remap[index] = output.count
            output.append(XMLNode(parent: parent, content: content, location: node.location))
        }
        guard source.nodes.indices.contains(source.rootIndex), let root = remap[source.rootIndex] else {
            throw URDFFailure(.invalid("export root"))
        }
        return XMLDocument(declaration: source.declaration, nodes: output, rootIndex: root)
    }
}

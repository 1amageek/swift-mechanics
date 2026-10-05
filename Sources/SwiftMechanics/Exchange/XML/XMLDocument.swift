public struct XMLDocument: Sendable {
    public let declaration: XMLDeclaration?
    public let nodes: [XMLNode]
    public let rootIndex: Int
    /// Construction is untrusted; encoding validates the complete table transactionally.
    public init(declaration: XMLDeclaration? = nil, nodes: [XMLNode], rootIndex: Int) {
        self.declaration = declaration; self.nodes = nodes; self.rootIndex = rootIndex
    }
}

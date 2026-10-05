public struct MJCFLoss: Sendable {
    public let category: MJCFLossCategory
    public let node: Int
    public let field: String
    public let reason: String
    public let source: SourceProvenance
    internal init(category: MJCFLossCategory, node: Int, field: String, reason: String, source: SourceProvenance) {
        self.category = category; self.node = node; self.field = field; self.reason = reason; self.source = source
    }
}

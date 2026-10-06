public struct MJCFEntityBinding: Sendable {
    public let node: Int
    public let originalName: String
    public let entity: EntityID
    public let effectiveAttributes: [MJCFEffectiveAttribute]
    internal init(node: Int, originalName: String, entity: EntityID, effectiveAttributes: [MJCFEffectiveAttribute]) {
        self.node = node; self.originalName = originalName; self.entity = entity; self.effectiveAttributes = effectiveAttributes
    }
}

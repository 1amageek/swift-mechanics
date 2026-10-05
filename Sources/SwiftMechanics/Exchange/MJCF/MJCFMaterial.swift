/// Retained visual description; does not assert contact or renderer execution.
public struct MJCFMaterial: Sendable {
    public let name: String
    public let node: Int
    public let entity: EntityID
    public let attributes: [MJCFEffectiveAttribute]
    internal init(name: String, node: Int, entity: EntityID, attributes: [MJCFEffectiveAttribute]) { self.name = name; self.node = node; self.entity = entity; self.attributes = attributes }
}

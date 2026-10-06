public struct MJCFEffectiveAttribute: Sendable {
    public let name: String
    public let value: String
    public let definingNode: Int
    public let inherited: Bool
    internal init(name: String, value: String, definingNode: Int, inherited: Bool) {
        self.name = name; self.value = value; self.definingNode = definingNode; self.inherited = inherited
    }
}

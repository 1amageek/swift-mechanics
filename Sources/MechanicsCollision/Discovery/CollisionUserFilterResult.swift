public struct CollisionUserFilterResult: Sendable {
    public let allowed: Bool
    public let operations: Int
    public init(allowed: Bool, operations: Int) { self.allowed = allowed; self.operations = operations }
}

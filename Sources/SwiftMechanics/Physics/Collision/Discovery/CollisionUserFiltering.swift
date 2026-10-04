public protocol CollisionUserFiltering: Sendable {
    func decide(first: CollisionProxy, second: CollisionProxy, remainingOperations: Int) throws(CollisionError) -> CollisionUserFilterResult
}

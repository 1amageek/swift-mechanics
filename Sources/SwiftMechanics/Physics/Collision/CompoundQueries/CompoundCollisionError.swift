public enum CompoundCollisionError: Error, Equatable, Sendable {
    case collision(CollisionError)
    case core(CoreError)
    case model(ModelError)
    case invalidIdentity
    case invalidChildren
    case invalidUnit
    case unsupportedUserFilterAccounting
    case staleRevision(expected: UInt64, actual: UInt64)
    case frameMismatch
    case metadataLimit(limit: Int)
    case child(first: EntityID, second: EntityID?, cause: CollisionError)
}

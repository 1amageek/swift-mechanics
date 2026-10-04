
public enum CollisionError: Error, Equatable, Sendable {
    case core(CoreError)
    case model(ModelError)
    case invalidShape
    case invalidPolicy
    case invalidIdentity
    case invalidReference
    case frameMismatch
    case staleGeometry
    case unsupportedPair
    case unsupportedQuery
    case unsupportedSweep
    case invalidRay
    case invalidFilterReport
    case invalidLifecycle
    case arithmeticFailure
    case resourceLimit(resource: CollisionResource, limit: Int)
    case cancelled
    case geometricResidual(value: Double, threshold: Double)
    case nonConvergence(iterations: Int)
    case unresolvedMinimum(separation: Double)
    case approximationExceeded(value: Double, maximum: Double)
}

internal func collisionCore<Value>(_ operation: () throws(CoreError) -> Value) throws(CollisionError) -> Value {
    do { return try operation() } catch { throw .core(error) }
}

internal func collisionFinite(_ value: Double) throws(CollisionError) -> Double {
    guard value.isFinite else { throw .arithmeticFailure }
    return value
}

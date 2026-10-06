public enum ConvexCollisionError: Error, Equatable, Sendable {
    case collision(CollisionError)
    case unsupportedShape
    case invalidShape
    case degenerateSimplex
    case unresolvedInteriorSeed
    case duplicateSupport
    case invalidPolytope
    case residualRejected(value: Double, threshold: Double)
    case nonConvergence(iterations: Int)
}

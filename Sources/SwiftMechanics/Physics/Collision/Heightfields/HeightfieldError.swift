public enum HeightfieldError: Error, Equatable, Sendable {
    case core(CoreError)
    case model(ModelError)
    case collision(CollisionError)
    case invalidIdentity
    case invalidGrid
    case invalidPolicy
    case arithmeticFailure
    case degenerateTriangle(row: Int, column: Int, half: Int)
    case staleReference
    case frameMismatch
    case forbiddenMotion
    case unsupportedShape
    case unsupportedSignedSolid
    case ambiguousRay
    case ambiguousOverlap(clearance: Double)
    case resolutionExceeded(value: Double, maximum: Double)
    case originalResidual(value: Double, threshold: Double)
}

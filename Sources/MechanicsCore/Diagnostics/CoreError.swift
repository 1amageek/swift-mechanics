public enum CoreError: Error, Equatable, Sendable {
    case nonFiniteInput
    case nonFiniteResult
    case invalidIndex
    case invalidTolerance
    case degenerateVector
    case degenerateQuaternion
    case singularMatrix
    case nonRigidMatrix
    case invalidTimeStep
    case invalidMass
    case dimensionMismatch
    case dimensionExponentOverflow
    case invalidUnitScale
    case invalidUnitOffset
}

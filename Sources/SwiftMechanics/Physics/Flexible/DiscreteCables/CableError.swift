public enum CableError: Error, Equatable, Sendable {
    case invalidInput
    case layoutMismatch
    case duplicateNode
    case degenerateSegment(index: Int)
    case outsideAxialDomain(index: Int)
    case nonsmoothStretch(index: Int)
    case unsupportedTwist
    case nonFiniteResult
    case capacityExceeded
    case cancelled
    case acceptanceFailed
    case attemptLimit
    case minimumSubstep
    case numerical(NumericalError)
    case core(CoreError)
}

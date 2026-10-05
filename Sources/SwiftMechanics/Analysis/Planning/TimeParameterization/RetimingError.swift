public enum RetimingError: Error, Sendable {
    case invalidInput
    case invalidPolicy
    case identityMismatch
    case unsupportedDomain
    case nonFiniteArithmetic
    case capacityExceeded
    case cancelled
    case outsideClockDomain
    case infeasibleStaticEffort(coordinate: Int)
    case infeasibleMotion(segment: Int, coordinate: Int)
    case durationLimit(segment: Int)
    case totalDurationLimit
    case continuousLimitRejected(segment: Int, coordinate: Int)
    case physicalReplayRejected(segment: Int, coordinate: Int)
    case kinematicSupplierFailure
    case dynamics(DynamicsError)
    case numerical(NumericalError)
    case core(CoreError)
}

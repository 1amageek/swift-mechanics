public enum RollingError: Error, Sendable {
    case invalidInput
    case invalidChart
    case staleSource
    case stalePlaneSample
    case undefinedContact(gap: Double)
    case unsupportedDomain
    case rankDeficient(rank: Int, rows: Int)
    case inconsistentKinematics(rowID: UInt64)
    case capacityExceeded
    case cancelled
    case nonFiniteResult
    case numerical(NumericalError)
    case compilation(CompilationFailure)
    case joints(JointError)
    case geometry(CoreError)
    case supplier(any Error)
}

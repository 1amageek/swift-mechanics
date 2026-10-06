public enum ExternalCommandError: Error, Sendable {
    case invalidPolicy, invalidIdentity, incompatibleBinding, incompatibleUnit
    case invalidTime, invalidCheckpoint, outOfOrder, stalePacket, staleTick
    case synchronizationUnavailable, ageExceeded, gapExceeded, nonfiniteResult
    case capacity(resource: String, limit: Int), integerOverflow, cancelled
    case core(CoreError), actuation(ActuationError)
    indirect case control(ControlFailure)
}

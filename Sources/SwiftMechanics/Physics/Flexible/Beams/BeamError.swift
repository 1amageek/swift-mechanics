public enum BeamError: Error, Sendable, Equatable {
    case invalidInput, capacityExceeded, cancelled, nonFiniteResult
    case numerical(NumericalError)
}

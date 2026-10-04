
public enum ComplementarityError: Error, Equatable, Sendable {
    case numerical(NumericalError)
    case invalidIdentity
    case invalidCone(block: Int)
    case unsupportedLaw
    case staleCache
    case invalidRestart

    public var termination: NumericalTermination {
        switch self {
        case .numerical(let error): error.termination
        case .invalidIdentity, .invalidCone, .staleCache, .invalidRestart: .invalidInput
        case .unsupportedLaw: .unsupportedCapability
        }
    }
}

internal func complementarityNumerical<Value>(_ operation: () throws(NumericalError) -> Value) throws(ComplementarityError) -> Value {
    do { return try operation() } catch { throw .numerical(error) }
}

internal func complementarityFinite(_ value: Double) throws(ComplementarityError) -> Double {
    guard value.isFinite else { throw .numerical(.nonFiniteResult) }
    return value
}

internal func complementarityCancelled() throws(ComplementarityError) {
    guard !Task.isCancelled else { throw .numerical(.cancelled) }
}

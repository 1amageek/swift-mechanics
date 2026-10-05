public enum ExternalCommandInterpolation: UInt8, Equatable, Sendable {
    case exact = 0
    case zeroOrderHold
    case linear
}

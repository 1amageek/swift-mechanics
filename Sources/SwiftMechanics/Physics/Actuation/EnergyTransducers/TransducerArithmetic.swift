internal enum TransducerArithmetic {
    static func finite(_ value: Double) throws(ActuationError) -> Double {
        guard value.isFinite else { throw .nonfiniteResult }
        return value
    }
    static func preflight(position: Double, state: Double, work: inout ActuationWork) throws(ActuationError) {
        try work.reserve(scalars: 24); try work.charge(64)
        guard position.isFinite, state.isFinite else { throw .invalidInput }
    }
}

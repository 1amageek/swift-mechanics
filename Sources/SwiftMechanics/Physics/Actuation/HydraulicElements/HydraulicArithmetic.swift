internal enum HydraulicArithmetic {
    static func finite(_ value: Double) throws(ActuationError) -> Double {
        guard value.isFinite else { throw .nonfiniteResult }
        return value
    }
    static func preflight(_ work: inout ActuationWork, cylinder: Bool = false) throws(ActuationError) {
        try work.reserve(scalars: cylinder ? 32 : 16)
        try work.charge(cylinder ? 96 : 32)
    }
}

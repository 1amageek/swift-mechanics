internal enum LinearProgramArithmetic {
    static func finite(_ value: Double) throws(LinearProgramCause) -> Double {
        guard value.isFinite else { throw .nonFiniteArithmetic }; return value
    }
    static func checkpoint(_ policy: LinearProgramPolicy) throws(LinearProgramCause) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
    }
    static func charge(_ count: Int, policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) {
        try checkpoint(policy)
        do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func product(_ a: Int, _ b: Int) throws(LinearProgramCause) -> Int {
        do { return try NumericalWork.product(a, b) } catch { throw .numerical(error) }
    }
    static func metadataCount(_ string: String, policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> Int {
        var count = 0
        for _ in string.utf8 {
            try charge(1, policy: policy, work: &work)
            count = try sum(count, 1)
        }
        return count
    }
    static func sum(_ a: Int, _ b: Int) throws(LinearProgramCause) -> Int {
        do { return try NumericalWork.sum(a, b) } catch { throw .numerical(error) }
    }
    static func threshold(_ tolerance: NumericalTolerance, scale: Double) throws(LinearProgramCause) -> Double {
        guard scale.isFinite, scale >= 0 else { throw .nonFiniteArithmetic }
        return try finite(tolerance.absolute + tolerance.relative * scale)
    }
    static func residual(_ error: Double, scale: Double, tolerance: NumericalTolerance) throws(LinearProgramCause) -> Double {
        let magnitude = abs(try finite(error))
        let limit = try threshold(tolerance, scale: scale)
        if limit == 0 { guard magnitude == 0 else { throw .certificateRejected }; return 0 }
        let normalized = try finite(magnitude / limit)
        guard normalized <= 1 else { throw .certificateRejected }; return normalized
    }
}

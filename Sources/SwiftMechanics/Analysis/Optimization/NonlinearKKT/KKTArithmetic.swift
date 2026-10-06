internal enum KKTArithmetic {
    static let invalidLedgerCode=Int.min
    static func check(_ cancelled: @Sendable () -> Bool) throws(NonlinearCause) {
        guard !Task.isCancelled, !cancelled() else { throw .numerical(.cancelled) }
    }
    static func charge(_ count: Int,work: inout NumericalWork,cancelled: @Sendable () -> Bool) throws(NonlinearCause) {
        try check(cancelled); do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func sum(_ a: Int,_ b: Int) throws(NonlinearCause) -> Int { do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) } }
    static func product(_ a: Int,_ b: Int) throws(NonlinearCause) -> Int { do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) } }
    static func finite<Scalar: NumericalScalar>(_ value: Scalar) throws(NonlinearCause) -> Scalar { guard value.isFinite else { throw .numerical(.nonFiniteResult) }; return value }
    static func ledgerUnavailable(_ cause: NonlinearCause) -> Bool { cause == .equation(.evaluationFailed(code:invalidLedgerCode)) }
}

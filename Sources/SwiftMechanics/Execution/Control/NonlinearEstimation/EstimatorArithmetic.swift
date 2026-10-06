internal enum EstimatorArithmetic {
    static func check(_ p: NonlinearEstimatorPolicy) throws(NonlinearEstimatorCause) {
        guard !Task.isCancelled, !p.isCancelled(), !p.derivatives.isCancelled(), !p.observations.isCancelled() else { throw .cancelled }
    }
    static func charge(_ n: Int, policy: NonlinearEstimatorPolicy, work: inout NumericalWork) throws(NonlinearEstimatorCause) {
        try check(policy); do { try work.chargeOperations(n) } catch { throw .numerical(error) }
    }
    static func finite(_ x: Double) throws(NonlinearEstimatorCause) -> Double {
        guard x.isFinite else { throw .invalidSupplierOutput }; return x
    }
    static func agreement(_ a: Double, _ b: Double, _ tolerance: NumericalTolerance) throws(NonlinearEstimatorCause) -> Bool {
        let difference = try finite(a-b)
        do { return try tolerance.contains(error: difference, scale: max(abs(a), abs(b))) }
        catch { throw .physicalEvidenceRejected }
    }
    static func reserve(_ n: Int, policy: NonlinearEstimatorPolicy, work: inout NumericalWork) throws(NonlinearEstimatorCause) {
        guard n <= policy.maximumScalarStorage else { throw .capacityExceeded }
        do { try work.requireStorage(n) } catch { throw .numerical(error) }
    }
    static func nested(_ outer: NumericalWork, reserved: Int, policy: NonlinearEstimatorPolicy) throws(NonlinearEstimatorCause) -> NumericalWork {
        do {
            let budget = try outer.remainingBudget(reservedStorage: reserved)
            guard reserved <= policy.maximumScalarStorage else { throw NonlinearEstimatorCause.capacityExceeded }
            return NumericalWork(budget: try NumericalBudget(scalarStorage: min(budget.scalarStorage, policy.maximumScalarStorage-reserved),
                arithmeticOperations: budget.arithmeticOperations, iterations: budget.iterations))
        } catch let error as NonlinearEstimatorCause { throw error }
        catch let error as NumericalError { throw .numerical(error) }
        catch { throw .invalidSupplierOutput }
    }
    static func absorb(_ inner: NumericalWork, into outer: inout NumericalWork, reserved: Int) throws(NonlinearEstimatorCause) {
        do { try outer.absorb(inner, reservedStorage: reserved) } catch { throw .numerical(error) }
    }
}

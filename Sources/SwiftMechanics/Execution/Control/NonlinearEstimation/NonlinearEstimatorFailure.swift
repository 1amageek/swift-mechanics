public struct NonlinearEstimatorFailure: Error, Sendable {
    public let cause: NonlinearEstimatorCause
    public let phase: String
    public let work: NumericalWork
    public let derivativeCalls: Int
    public let failedSupplierWorkUnavailable: Bool
    internal init(cause: NonlinearEstimatorCause, phase: String, work: NumericalWork, derivativeCalls: Int) {
        self.cause = cause; self.phase = phase; self.work = work; self.derivativeCalls = derivativeCalls
        switch cause {
        case .compilation: failedSupplierWorkUnavailable = true
        case .dynamics(let error): failedSupplierWorkUnavailable = error.failedSupplierWorkUnavailable
        case .linear(_, let unavailable): failedSupplierWorkUnavailable = unavailable
        case .observations(let error): failedSupplierWorkUnavailable = error.failedSupplierWorkUnavailable
        case .derivatives(let error):
            switch error {
            case .invalidSupplierLedger(let unavailable), .joints(_, let unavailable), .constraints(_, let unavailable), .dynamics(_, let unavailable):
                failedSupplierWorkUnavailable = unavailable
            default: failedSupplierWorkUnavailable = false
            }
        default: failedSupplierWorkUnavailable = false
        }
    }
}

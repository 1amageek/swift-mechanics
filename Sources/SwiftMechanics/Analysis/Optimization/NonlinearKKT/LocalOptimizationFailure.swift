public struct LocalOptimizationFailure: Error, Sendable {
    public let cause: LocalOptimizationCause, phase: LocalOptimizationPhase, work: NumericalWork
    public let failedSupplierWorkUnavailable: Bool
    public let lastOriginalKKTResidual: Double?
    internal init(cause: LocalOptimizationCause,phase: LocalOptimizationPhase,work: NumericalWork,unavailable: Bool,residual: Double?) {
        self.cause=cause; self.phase=phase; self.work=work; failedSupplierWorkUnavailable=unavailable; lastOriginalKKTResidual=residual
    }
}

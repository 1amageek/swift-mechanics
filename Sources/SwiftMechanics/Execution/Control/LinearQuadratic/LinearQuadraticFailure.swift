public struct LinearQuadraticFailure: Error, Sendable {
    public enum Cause: Error, Sendable {
        case invalidInput, capacity, incompatiblePort, provenanceMismatch, cancelled
        case nonsymmetricCost, indefiniteStateCost, stabilizabilityWitnessRejected
        case originalEvidenceRejected, invalidSupplierOutput, invalidSupplierLedger
        case nonconvergence(iterations: Int, residual: Double)
        case numerical(NumericalError)
    }
    public let cause: Cause
    public let phase: String
    public let knownWork: NumericalWork?
    public let failedSupplierWorkUnavailable: Bool
    public init(_ cause: Cause, phase: String, knownWork: NumericalWork? = nil, failedSupplierWorkUnavailable: Bool = false) {
        self.cause = cause; self.phase = phase; self.knownWork = knownWork
        self.failedSupplierWorkUnavailable = failedSupplierWorkUnavailable
    }
    internal func retaining(_ work: NumericalWork) -> Self {
        Self(cause, phase: phase, knownWork: work, failedSupplierWorkUnavailable: failedSupplierWorkUnavailable)
    }
}

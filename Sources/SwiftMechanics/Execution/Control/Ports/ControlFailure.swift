public struct ControlFailure: Error, Sendable {
    public enum Cause: Error, Sendable {
        case invalidInput, unsupportedDomain, staleSample, incompatiblePort, algebraicLoop, capacity, cancelled, busy
        case invalidSupplierLedger, invalidSupplierOutput, originalEvidenceRejected
        case numerical(NumericalError), actuation(ActuationError), dynamics(DynamicsError)
        // Preserve rich immutable supplier evidence without multiplying its inline layout in typed-throws temporaries.
        indirect case integration(IntegrationFailure), runtime(RuntimeFailure)
    }
    public let cause: Cause
    public let phase: String
    public let failedSupplierWorkUnavailable: Bool
    public let numericalWork:NumericalWork?
    public let actuationWork:ActuationWork?
    public init(_ cause: Cause, phase: String, failedSupplierWorkUnavailable: Bool = false, numericalWork:NumericalWork? = nil, actuationWork:ActuationWork? = nil) {
        self.cause=cause;self.phase=phase;self.failedSupplierWorkUnavailable=failedSupplierWorkUnavailable;self.numericalWork=numericalWork;self.actuationWork=actuationWork
    }
    internal func retaining(numerical:NumericalWork?,actuation:ActuationWork) -> ControlFailure {
        ControlFailure(cause,phase:phase,failedSupplierWorkUnavailable:failedSupplierWorkUnavailable,numericalWork:numerical,actuationWork:actuation)
    }
}

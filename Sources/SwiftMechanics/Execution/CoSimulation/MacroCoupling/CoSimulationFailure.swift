public struct CoSimulationFailure: Error, Sendable {
    public enum Cause: Error, Sendable {
        case invalidInput, unsupportedDomain, staleBoundary, busy, closed, poisoned, cancelled
        case capacity, originalEvidenceRejected, irrecoverablePrefix, unavailableSupplierWork
        indirect case control(ControlFailure)
        case observation(ObservationError), numerical(NumericalError)
    }
    public let cause: Cause
    public let firstPrefix: CoSimulationOwnerPrefix?
    public let secondPrefix: CoSimulationOwnerPrefix?
    public let recoveryFailures: [CoSimulationFailure]
    public let work: CoSimulationWorkLedger?
    public let failedSupplierWorkUnavailable: Bool
    public let supplierAcceptedPrefix: RuntimeAcceptedState?
    internal init(_ cause: Cause, first: CoSimulationOwnerPrefix? = nil, second: CoSimulationOwnerPrefix? = nil,
                  recovery: [CoSimulationFailure] = [], work: CoSimulationWorkLedger? = nil, unavailable: Bool = false, supplierAcceptedPrefix: RuntimeAcceptedState? = nil) {
        self.cause=cause; firstPrefix=first; secondPrefix=second; recoveryFailures=recovery
        self.work=work; failedSupplierWorkUnavailable=unavailable; self.supplierAcceptedPrefix=supplierAcceptedPrefix
    }
    internal static func refusal(_ cause: Cause) -> Self { Self(cause) }
    internal static func control(_ error: ControlFailure) -> Self {
        Self(.control(error), unavailable: error.failedSupplierWorkUnavailable)
    }
    internal var supplierPrefix: RuntimeAcceptedState? {
        if let supplierAcceptedPrefix { return supplierAcceptedPrefix }
        if case .control(let error)=cause {
            switch error.cause {
            case .runtime(let failure): return failure.lastAccepted
            case .integration(let failure): return failure.lastAccepted
            default: return nil
            }
        }
        return nil
    }
}

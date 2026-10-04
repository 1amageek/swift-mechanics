public enum MechanismSleepFailure:Error,Sendable {
    case preflight(RuntimeFailure,accepted:RuntimeAcceptedState)
    case integration(IntegrationFailure)
    public var lastAccepted:RuntimeAcceptedState {
        switch self { case .preflight(_,let accepted):return accepted;case .integration(let failure):return failure.lastAccepted }
    }
    public var failedSupplierWorkUnavailable:Bool {
        switch self { case .preflight(let failure,_):return failure.failedSupplierWorkUnavailable;case .integration(let failure):return failure.cause.failedSupplierWorkUnavailable }
    }
}

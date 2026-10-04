public enum LoadedMechanismSleepFailure:Error,Sendable {
    case preflight(RuntimeFailure,accepted:RuntimeAcceptedState,loads:StationaryLoadWorkReport)
    case integration(IntegrationFailure,loads:StationaryLoadWorkReport)
    case wake(RuntimeFailure,accepted:RuntimeAcceptedState,loads:StationaryLoadWorkReport)
    public var loads:StationaryLoadWorkReport { switch self { case .preflight(_,_,let value),.integration(_,let value),.wake(_,_,let value):value } }
    public var accepted:RuntimeAcceptedState { switch self { case .preflight(_,let value,_),.wake(_,let value,_):value;case .integration(let failure,_):failure.lastAccepted } }
    public var failedSupplierWorkUnavailable:Bool {
        if loads.failedSupplierWorkUnavailable { return true }
        switch self { case .preflight(let failure,_,_),.wake(let failure,_,_):return failure.failedSupplierWorkUnavailable;case .integration(let failure,_):return failure.cause.failedSupplierWorkUnavailable }
    }
}

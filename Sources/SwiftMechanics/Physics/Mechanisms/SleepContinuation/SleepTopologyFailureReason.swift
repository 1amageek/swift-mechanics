public enum SleepTopologyFailureReason: Error, Sendable {
    case unsupportedDomain,staleSource,invalidDisposition,capacityExceeded,cancelled,supplierWorkUnavailable
    case runtime(RuntimeFailure)
    case mechanism(MechanismError)
    case numerical(NumericalError)
}

public enum SensorPipelineFailure: Error, Sendable {
    case invalidDefinition, unsupportedDomain, staleSource, nonfinite, capacityExceeded, corruptState
    case overrun(retainedAfter: UInt64), incompatibleSchema, invalidLease, busy, closed, cancelled
    indirect case observation(ObservationError, operations: Int)
    indirect case runtime(RuntimeFailure)
    indirect case load(LoadError)

    internal var runtimeFailure: RuntimeFailure {
        switch self {
        case .runtime(let failure): return failure
        case .observation(let failure, _):
            return RuntimeFailure(failure.isCancellation ? .cancelled : .invalidContributor,
                message: "Sensor pipeline raw observation failed.", failedSupplierWorkUnavailable: failure.failedSupplierWorkUnavailable)
        case .capacityExceeded, .overrun: return RuntimeFailure(.capacityExceeded, message: "Sensor pipeline capacity or retained sequence exceeded.")
        case .busy: return RuntimeFailure(.busy, message: "Sensor pipeline operation is busy.")
        case .closed, .invalidLease: return RuntimeFailure(.closed, message: "Sensor pipeline owner or lease is closed.")
        case .cancelled: return RuntimeFailure(.cancelled, message: "Sensor pipeline operation cancelled.")
        case .unsupportedDomain: return RuntimeFailure(.unsupportedDomain, message: "Sensor pipeline domain is unsupported.")
        default: return RuntimeFailure(.invalidContributor, message: "Sensor pipeline source/schema/state validation failed.")
        }
    }
}

private extension ObservationError {
    var isCancellation: Bool { if case .cancelled = self { true } else { false } }
}

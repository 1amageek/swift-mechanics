public struct RuntimeProfile: Equatable, Sendable {
    public let workload: String
    public let attemptedTransactions: UInt64
    public let committedTransactions: UInt64
    public let rejectedTransactions: UInt64
    public let failedTransactions: UInt64
    public let reservedPhysicalScalars: Int
    public let physicalScalarCopyUpperBoundPerBufferDetachment: Int
    public let allocationMeasurement: RuntimeMeasurement
    public let residualMeasurement: RuntimeMeasurement
    internal init(workload: String, attempted: UInt64, committed: UInt64, rejected: UInt64, failed: UInt64, scalars: Int) {
        self.workload = workload; attemptedTransactions = attempted; committedTransactions = committed
        rejectedTransactions = rejected; failedTransactions = failed; reservedPhysicalScalars = scalars
        physicalScalarCopyUpperBoundPerBufferDetachment = scalars
        allocationMeasurement = .unavailable(reason: "Allocator traffic is not instrumented in this workload.")
        residualMeasurement = .unavailable(reason: "No solver residual measurement provider is integrated.")
    }
    public func duration(for phase: RuntimePhase) -> RuntimeMeasurement {
        .unavailable(reason: "End-to-end phase timing requires a separately qualified measurement provider.")
    }
    public func requireMeasuredEndToEndProfile() throws(RuntimeFailure) {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Profiling consumers call this baseline requirement.
        // Full phase timing/residual/allocator instrumentation must be supplied and behaviorally proved before success.
        throw RuntimeFailure(.profilingUnavailable, message: "Measured end-to-end profile is unavailable in this initial transaction domain.")
    }
}

import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class RuntimeCancellationSource: Sendable {
    private struct ControlState: Sendable { var cancelled = false; var work = 0 }
    private let state = Mutex(ControlState())
    private let total: Int
    private let quantum: Int
    internal init(capacity: RuntimeCapacity) { total = capacity.maximumStepWorkUnits; quantum = capacity.maximumWorkBetweenSafePoints }
    public func cancel() { state.withLock { $0.cancelled = true } }
    public var admittedWorkUnits: Int { state.withLock { $0.work } }
    public func check() throws(RuntimeFailure) {
        guard !state.withLock({ $0.cancelled }), !Task.isCancelled else { throw RuntimeFailure(.cancelled, message: "Runtime operation cancelled at a safe point.") }
    }
    internal func admitWork(_ units: Int) throws(RuntimeFailure) {
        guard !Task.isCancelled else { throw RuntimeFailure(.cancelled, message: "Runtime work cancelled before admission.") }
        try state.withLock { (value: inout ControlState) throws(RuntimeFailure) in
            guard !value.cancelled else { throw RuntimeFailure(.cancelled, message: "Runtime work cancelled before admission.") }
            guard units >= 0, units <= quantum else { throw RuntimeFailure(.capacityExceeded, message: "Work block exceeds safe-point quantum.") }
            let next = try RuntimeCounts.sum(value.work, units)
            guard next <= total else { throw RuntimeFailure(.capacityExceeded, message: "Step work budget exhausted.") }
            value.work = next
        }
    }
}

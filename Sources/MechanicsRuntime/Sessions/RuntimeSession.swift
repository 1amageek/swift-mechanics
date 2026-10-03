import Synchronization
import MechanicsCompiler
import MechanicsJoints

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class RuntimeSession<Checkpoints: RuntimeCheckpointHandling>: RuntimeSessionOperating, Sendable {
    public let configuration: RuntimeConfiguration
    private let checkpoints: Checkpoints
    private let storage: Mutex<RuntimeSessionMetadata>
    private let onRelease: (@Sendable () -> Void)?

    public init(model: CompiledMechanicalModel, configuration: RuntimeConfiguration, initialState: KinematicState,
                contributors: [RuntimeContributorState], seed: UInt64, checkpoints: Checkpoints,
                onRelease: (@Sendable () -> Void)? = nil) throws(RuntimeFailure) {
        self.configuration = configuration; self.checkpoints = checkpoints; self.onRelease = onRelease
        do throws(RuntimeFailure) {
            let checkpoint = try RuntimeCheckpoint(model: model.stamp, continuation: configuration.continuation, physical: initialState,
                contributors: contributors, random: RuntimeRandomState(seed: seed), acceptedSteps: 0)
            let accepted = try checkpoints.admit(checkpoint, model: model, configuration: configuration, cancellation: nil)
            try Self.verify(accepted, requested: checkpoint, model: model, configuration: configuration)
            self.storage = Mutex(try RuntimeSessionMetadata(model: model, accepted: accepted, capacity: configuration.capacity))
        } catch {
            onRelease?()
            throw error
        }
    }
    deinit { _ = shutdown() }

    public func snapshot() -> RuntimeAcceptedState { storage.withLock { $0.accepted } }
    public func profile() -> RuntimeProfile {
        storage.withLock { value in RuntimeProfile(workload: configuration.workload, attempted: value.attempted,
            committed: value.committed, rejected: value.rejected, failed: value.failed, scalars: value.scalarSlots) }
    }
    private static func verify(_ accepted: RuntimeAcceptedState, requested: RuntimeCheckpoint,
                               model: CompiledMechanicalModel, configuration: RuntimeConfiguration) throws(RuntimeFailure) {
        let value = accepted.checkpoint
        guard accepted.physical.stamp == model.stamp, value.model == model.stamp,
              value.continuation == configuration.continuation, accepted.physical.state == value.physical,
              value.physical == requested.physical, value.random == requested.random, value.acceptedSteps == requested.acceptedSteps,
              value.contributors == requested.contributors.sorted(by: { $0.id < $1.id }),
              value.contributors.count == configuration.requiredContributors.count else {
            throw RuntimeFailure(.invalidOwnerAccess, message: "Admission returned altered model/state/continuation/contributor data.")
        }
        for (record, schema) in zip(value.contributors, configuration.requiredContributors) {
            guard record.id == schema.id, record.category == schema.category, record.version == schema.version,
                  record.bytes.count <= schema.maximumBytes else { throw RuntimeFailure(.invalidContributor, contributor: record.id, message: "Final required contributor completeness check failed.") }
        }
    }
    private func acquire() throws(RuntimeFailure) -> RuntimeOperationLease {
        let source = RuntimeCancellationSource(capacity: configuration.capacity)
        return try storage.withLock { (value: inout RuntimeSessionMetadata) throws(RuntimeFailure) in
            guard !value.closing, !value.closed else { throw RuntimeFailure(.closed, message: "Runtime owner is closing/closed.", lastAccepted: value.accepted) }
            guard value.activeTicket == nil, value.observers == 0 else { throw RuntimeFailure(.busy, message: "Runtime owner already has an active operation/observation.", lastAccepted: value.accepted) }
            guard !Task.isCancelled else { throw RuntimeFailure(.cancelled, message: "Runtime transaction cancelled before checkout.", lastAccepted: value.accepted) }
            guard value.attempted < configuration.capacity.maximumTransactions else { throw RuntimeFailure(.capacityExceeded, message: "Runtime transaction capacity exhausted.", lastAccepted: value.accepted) }
            guard let workspace = value.workspace else { throw RuntimeFailure(.invalidOwnerAccess, message: "Exclusive workspace is missing.", lastAccepted: value.accepted) }
            value.attempted += 1; value.activeTicket = value.attempted; value.activeSource = source; value.cancelRequested = false
            value.workspace = nil
            return RuntimeOperationLease(ticket: value.attempted, model: value.model, accepted: value.accepted, source: source, workspace: workspace)
        }
    }
    private func closeIfQuiescent(_ value: inout RuntimeSessionMetadata) -> RuntimeReleaseAction {
        if value.closing && value.activeTicket == nil && value.observers == 0 {
            let retired = value.workspace
            value.workspace = nil; value.closed = true
            let release = !value.releaseIssued; value.releaseIssued = true
            return RuntimeReleaseAction(status: .closed, release: release, source: value.activeSource, retiredWorkspace: retired)
        }
        return RuntimeReleaseAction(status: value.closed ? .closed : .draining, release: false, source: value.activeSource, retiredWorkspace: nil)
    }
    private func apply(_ action: RuntimeReleaseAction) {
        action.source?.cancel()
        // Retained backing cannot be destroyed while the metadata lock is held.
        withExtendedLifetime(action.retiredWorkspace) { if action.release { onRelease?() } }
    }
    private func finish(_ lease: RuntimeOperationLease, workspace: RuntimeTrial, candidate: RuntimeAcceptedState?,
                        rejected: Bool, failure: RuntimeFailure?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        let result: (RuntimeAcceptedState, RuntimeFailure?, RuntimeReleaseAction) = storage.withLock { value in
            guard value.activeTicket == lease.ticket, value.activeSource === lease.source, value.model.stamp == lease.model.stamp else {
                return (value.accepted, RuntimeFailure(.invalidOwnerAccess, message: "Commit ticket/model/source binding is invalid.", lastAccepted: value.accepted),
                    RuntimeReleaseAction(status: .draining, release: false, source: nil, retiredWorkspace: nil))
            }
            var finalFailure = failure
            if finalFailure == nil && (value.cancelRequested || value.closing || Task.isCancelled) {
                finalFailure = RuntimeFailure(value.closing ? .closed : .cancelled, message: "Transaction publication cancelled by owner lifecycle.")
            }
            if let candidate, finalFailure == nil { value.accepted = candidate; value.committed += 1 }
            else if rejected && finalFailure == nil { value.rejected += 1 }
            else { value.failed += 1 }
            value.workspace = workspace; value.activeTicket = nil; value.activeSource = nil; value.cancelRequested = false
            let action = closeIfQuiescent(&value)
            return (value.accepted, finalFailure?.retaining(value.accepted), action)
        }
        lease.source.cancel()
        apply(result.2)
        if let failure = result.1 { throw failure }
        return result.0
    }

    public func performTrial(_ operation: @Sendable (inout RuntimeTrial, inout RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        let lease = try acquire()
        var workspace = lease.workspace, control = RuntimeStepControl(source: lease.source)
        var failure: RuntimeFailure?, candidate: RuntimeAcceptedState?, decision = RuntimeTrialDecision.reject
        do throws(RuntimeFailure) {
            try lease.source.check()
            try workspace.reset(from: lease.accepted, source: lease.source)
            decision = try operation(&workspace, &control)
            guard workspace.isBound(to: lease.source), control.isBound(to: lease.source) else { throw RuntimeFailure(.invalidOwnerAccess, message: "Callback replaced trial/control with another ticket.") }
            try lease.source.check()
            if decision == .accept {
                let requested = try workspace.checkpoint(from: lease.accepted)
                let validated = try checkpoints.admit(requested, model: lease.model, configuration: configuration, cancellation: lease.source)
                try Self.verify(validated, requested: requested, model: lease.model, configuration: configuration)
                candidate = validated
                try lease.source.check()
            }
        } catch { failure = bounded(error) }
        let accepted = try finish(lease, workspace: workspace.isBound(to: lease.source) ? workspace : lease.workspace, candidate: candidate, rejected: decision == .reject, failure: failure)
        return RuntimeTrialOutcome(decision: decision, accepted: accepted, admittedWorkUnits: lease.source.admittedWorkUnits)
    }
    public func restart(_ bytes: [UInt8], codec: any RuntimeCheckpointCoding) throws(RuntimeFailure) -> RuntimeAcceptedState {
        let lease = try acquire()
        var candidate: RuntimeAcceptedState?, failure: RuntimeFailure?
        do throws(RuntimeFailure) {
            try lease.source.check()
            let checkpoint = try codec.decode(bytes, capacity: configuration.capacity)
            let validated = try checkpoints.admit(checkpoint, model: lease.model, configuration: configuration, cancellation: lease.source)
            try Self.verify(validated, requested: checkpoint, model: lease.model, configuration: configuration)
            candidate = validated
            try lease.source.check()
        } catch { failure = bounded(error) }
        return try finish(lease, workspace: lease.workspace, candidate: candidate, rejected: false, failure: failure)
    }
    public func checkpoint(codec: any RuntimeCheckpointCoding) throws(RuntimeFailure) -> [UInt8] {
        let accepted = snapshot()
        do throws(RuntimeFailure) { return try codec.encode(accepted.checkpoint, capacity: configuration.capacity) }
        catch { throw bounded(error).retaining(accepted) }
    }
    private func bounded(_ failure: RuntimeFailure) -> RuntimeFailure {
        guard failure.message.utf8.count <= configuration.capacity.maximumMetadataBytes,
              (failure.contributor?.utf8.count ?? 0) <= configuration.capacity.maximumMetadataBytes else {
            return RuntimeFailure(.capacityExceeded, message: "Supplier diagnostic exceeds runtime metadata capacity.")
        }
        return failure
    }
    public func observe(_ operation: @Sendable (RuntimeAcceptedState) throws(RuntimeFailure) -> Void) throws(RuntimeFailure) {
        let accepted = try storage.withLock { (value: inout RuntimeSessionMetadata) throws(RuntimeFailure) in
            guard !value.closing, !value.closed else { throw RuntimeFailure(.closed, message: "Observation owner is closing/closed.", lastAccepted: value.accepted) }
            guard value.observers < configuration.capacity.maximumObservationLeases else { throw RuntimeFailure(.capacityExceeded, message: "Observation lease capacity exhausted.", lastAccepted: value.accepted) }
            value.observers += 1; return value.accepted
        }
        var failure: RuntimeFailure?
        do throws(RuntimeFailure) { try operation(accepted) }
        catch { failure = bounded(error) }
        let action = storage.withLock { value in
            value.observers -= 1; return closeIfQuiescent(&value)
        }
        apply(action)
        if let failure { throw failure.retaining(accepted) }
    }
    public func cancel() {
        let source = storage.withLock { value in
            if value.activeTicket != nil { value.cancelRequested = true }
            return value.activeSource
        }
        source?.cancel()
    }
    @discardableResult public func shutdown() -> RuntimeShutdownStatus {
        let action = storage.withLock { value in value.closing = true; return closeIfQuiescent(&value) }
        apply(action); return action.status
    }
    public func shutdownStatus() -> RuntimeShutdownStatus? {
        storage.withLock { value in value.closed ? .closed : (value.closing ? .draining : nil) }
    }
}

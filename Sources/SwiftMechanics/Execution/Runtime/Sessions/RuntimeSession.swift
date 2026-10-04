import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class RuntimeSession<Checkpoints: RuntimeCheckpointHandling>: RuntimeModelReplacing, Sendable {
    public var configuration: RuntimeConfiguration { storage.withLock { $0.context.configuration } }
    private let capacity: RuntimeCapacity
    private let storage: Mutex<RuntimeSessionMetadata>
    private let onRelease: (@Sendable () -> Void)?

    public init(model: CompiledMechanicalModel, configuration: RuntimeConfiguration, initialState: KinematicState,
                contributors: [RuntimeContributorState], seed: UInt64, checkpoints: Checkpoints,
                onRelease: (@Sendable () -> Void)? = nil) throws(RuntimeFailure) {
        self.capacity = configuration.capacity; self.onRelease = onRelease
        do throws(RuntimeFailure) {
            let checkpoint = try RuntimeCheckpoint(model: model.stamp, continuation: configuration.continuation, physical: initialState,
                contributors: contributors, random: RuntimeRandomState(seed: seed), acceptedSteps: 0)
            let accepted = try checkpoints.admit(checkpoint, model: model, configuration: configuration, cancellation: nil)
            try Self.verify(accepted, requested: checkpoint, model: model, configuration: configuration)
            let context=RuntimeSessionContext(model:model,configuration:configuration,checkpoints:checkpoints)
            let workspace = try RuntimeTrial(admission: _RuntimeTrialAdmission(accepted: accepted, capacity: capacity))
            self.storage = Mutex(try RuntimeSessionMetadata(context: context, accepted: accepted, workspace: workspace))
        } catch {
            onRelease?()
            throw error
        }
    }
    deinit { _ = shutdown() }

    public func snapshot() -> RuntimeAcceptedState { storage.withLock { $0.accepted } }
    public func profile() -> RuntimeProfile {
        storage.withLock { value in RuntimeProfile(workload: value.context.configuration.workload, attempted: value.attempted,
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
        let source = RuntimeCancellationSource(capacity: capacity)
        return try storage.withLock { (value: inout RuntimeSessionMetadata) throws(RuntimeFailure) in
            guard !value.closing, !value.closed else { throw RuntimeFailure(.closed, message: "Runtime owner is closing/closed.", lastAccepted: value.accepted) }
            guard value.activeTicket == nil, value.observers == 0 else { throw RuntimeFailure(.busy, message: "Runtime owner already has an active operation/observation.", lastAccepted: value.accepted) }
            guard !Task.isCancelled else { throw RuntimeFailure(.cancelled, message: "Runtime transaction cancelled before checkout.", lastAccepted: value.accepted) }
            guard value.attempted < capacity.maximumTransactions else { throw RuntimeFailure(.capacityExceeded, message: "Runtime transaction capacity exhausted.", lastAccepted: value.accepted) }
            guard let workspace = value.workspace else { throw RuntimeFailure(.invalidOwnerAccess, message: "Exclusive workspace is missing.", lastAccepted: value.accepted) }
            value.attempted += 1; value.activeTicket = value.attempted; value.activeSource = source; value.cancelRequested = false
            value.workspace = nil
            return RuntimeOperationLease(ticket: value.attempted, context:value.context, accepted: value.accepted, source: source, workspace: workspace)
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
                        rejected: Bool, failure: RuntimeFailure?, replacement: RuntimeReplacementPublication? = nil) throws(RuntimeFailure) -> RuntimeAcceptedState {
        let result: (RuntimeAcceptedState, RuntimeFailure?, RuntimeReleaseAction) = storage.withLock { value in
            guard value.activeTicket == lease.ticket, value.activeSource === lease.source, value.model.stamp == lease.model.stamp else {
                return (value.accepted, RuntimeFailure(.invalidOwnerAccess, message: "Commit ticket/model/source binding is invalid.", lastAccepted: value.accepted),
                    RuntimeReleaseAction(status: .draining, release: false, source: nil, retiredWorkspace: nil))
            }
            var finalFailure = failure
            if finalFailure == nil && (value.cancelRequested || value.closing || Task.isCancelled) {
                finalFailure = RuntimeFailure(value.closing ? .closed : .cancelled, message: "Transaction publication cancelled by owner lifecycle.")
            }
            if let candidate, finalFailure == nil {
                value.accepted = candidate; value.committed += 1
                if let replacement { value.context=replacement.context;value.scalarSlots=replacement.scalarSlots }
            }
            else if rejected && finalFailure == nil { value.rejected += 1 }
            else { value.failed += 1 }
            value.workspace = candidate != nil && finalFailure == nil ? (replacement?.workspace ?? workspace) : workspace
            value.activeTicket = nil; value.activeSource = nil; value.cancelRequested = false
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
        let admission = _RuntimeOperationAdmission(accepted: lease.accepted, source: lease.source)
        var workspace = lease.workspace, control = RuntimeStepControl(admission: admission)
        var failure: RuntimeFailure?, candidate: RuntimeAcceptedState?, decision = RuntimeTrialDecision.reject
        do throws(RuntimeFailure) {
            try lease.source.check()
            try workspace.reset(admission: admission)
            decision = try operation(&workspace, &control)
            guard workspace.isBound(to: lease.source), control.isBound(to: lease.source) else { throw RuntimeFailure(.invalidOwnerAccess, message: "Callback replaced trial/control with another ticket.") }
            try lease.source.check()
            if decision == .accept {
                let requested = try workspace.checkpoint(from: lease.accepted)
                let validated = try lease.context.checkpoints.admit(requested, model: lease.model, configuration: lease.context.configuration, cancellation: lease.source)
                try Self.verify(validated, requested: requested, model: lease.model, configuration: lease.context.configuration)
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
            let checkpoint = try codec.decode(bytes, capacity: capacity)
            let validated = try lease.context.checkpoints.admit(checkpoint, model: lease.model, configuration: lease.context.configuration, cancellation: lease.source)
            try Self.verify(validated, requested: checkpoint, model: lease.model, configuration: lease.context.configuration)
            candidate = validated
            try lease.source.check()
        } catch { failure = bounded(error) }
        return try finish(lease, workspace: lease.workspace, candidate: candidate, rejected: false, failure: failure)
    }
    @inline(never)
    public func replaceModel(_ request: RuntimeModelReplacement) throws(RuntimeFailure) -> RuntimeAcceptedState {
        let lease=try acquire()
        var candidate: RuntimeAcceptedState?, publication: RuntimeReplacementPublication?, failure: RuntimeFailure?
        do throws(RuntimeFailure) {
            try lease.source.check()
            let requested=try replacementCheckpoint(request,lease:lease)
            let context=RuntimeSessionContext(model:request.model,configuration:request.configuration,checkpoints:request.checkpoints)
            let validated=try context.checkpoints.admit(requested,model:context.model,configuration:context.configuration,cancellation:lease.source)
            try Self.verify(validated,requested:requested,model:context.model,configuration:context.configuration)
            try lease.source.check()
            let workspace = try RuntimeTrial(admission: _RuntimeTrialAdmission(accepted: validated, capacity: capacity))
            let count=try RuntimeCounts.physical(q:validated.physical.state.q.count,v:validated.physical.state.v.count)
            publication=RuntimeReplacementPublication(context:context,workspace:workspace,scalarSlots:count)
            candidate=validated
            try lease.source.check()
        } catch { failure=bounded(error) }
        return try finish(lease,workspace:lease.workspace,candidate:candidate,rejected:false,failure:failure,replacement:publication)
    }
    @inline(never)
    private func replacementCheckpoint(_ request: RuntimeModelReplacement, lease: RuntimeOperationLease) throws(RuntimeFailure) -> RuntimeCheckpoint {
        try boundComparison(request.expectedSource)
        guard request.expectedSource == lease.accepted.checkpoint else {
            throw RuntimeFailure(.incompatibleModel,message:"Replacement source is no longer the complete accepted checkpoint.")
        }
        guard request.model.stamp.identity == lease.model.stamp.identity,
              request.model.stamp.revision > lease.model.stamp.revision,
              request.physical.time == lease.accepted.physical.state.time else {
            throw RuntimeFailure(.incompatibleModel,message:"Replacement requires the same model identity, newer revision and accepted time.")
        }
        guard request.configuration.capacity == capacity else {
            throw RuntimeFailure(.capacityExceeded,message:"Replacement cannot change owner capacity.")
        }
        guard request.configuration.continuation == lease.context.configuration.continuation else {
            throw RuntimeFailure(.incompatibleContinuation,message:"Replacement cannot change continuation profile.")
        }
        guard request.configuration.determinism == lease.context.configuration.determinism else {
            throw RuntimeFailure(.unsupportedDeterminism,message:"Replacement cannot change determinism tier.")
        }
        guard lease.accepted.checkpoint.acceptedSteps < UInt64.max else {
            throw RuntimeFailure(.capacityExceeded,message:"Accepted replacement sequence overflow.")
        }
        let result=try RuntimeCheckpoint(model:request.model.stamp,continuation:request.configuration.continuation,
            physical:request.physical,contributors:request.contributors,random:lease.accepted.checkpoint.random,
            acceptedSteps:lease.accepted.checkpoint.acceptedSteps+1)
        try boundComparison(result)
        try lease.source.check()
        return result
    }
    private func boundComparison(_ checkpoint: RuntimeCheckpoint) throws(RuntimeFailure) {
        let count=try RuntimeCounts.physical(q:checkpoint.physical.q.count,v:checkpoint.physical.v.count)
        guard count <= capacity.maximumPhysicalScalars, checkpoint.physical.acceleration.count == checkpoint.physical.v.count,
              checkpoint.physical.prescribedAnchors.isEmpty,checkpoint.contributors.count <= capacity.maximumContributors else {
            throw RuntimeFailure(.capacityExceeded,message:"Replacement checkpoint comparison exceeds admitted shape/capacity.")
        }
        let continuationBytes=try RuntimeCounts.sum(checkpoint.continuation.build.utf8.count,
            RuntimeCounts.sum(checkpoint.continuation.backend.utf8.count,checkpoint.continuation.precision.utf8.count))
        var metadata=checkpoint.model.identity.utf8.count,payload=0
        guard metadata <= capacity.maximumMetadataBytes,continuationBytes <= capacity.maximumMetadataBytes else {
            throw RuntimeFailure(.capacityExceeded,message:"Replacement checkpoint metadata exceeds owner capacity.")
        }
        for record in checkpoint.contributors {
            metadata=try RuntimeCounts.sum(metadata,record.id.utf8.count);payload=try RuntimeCounts.sum(payload,record.bytes.count)
            guard metadata <= capacity.maximumMetadataBytes,payload <= capacity.maximumContributorBytes else {
                throw RuntimeFailure(.capacityExceeded,message:"Replacement contributor comparison exceeds owner capacity.")
            }
        }
    }
    public func checkpoint(codec: any RuntimeCheckpointCoding) throws(RuntimeFailure) -> [UInt8] {
        let accepted = snapshot()
        do throws(RuntimeFailure) { return try codec.encode(accepted.checkpoint, capacity: capacity) }
        catch { throw bounded(error).retaining(accepted) }
    }
    private func bounded(_ failure: RuntimeFailure) -> RuntimeFailure {
        guard failure.message.utf8.count <= capacity.maximumMetadataBytes,
              (failure.contributor?.utf8.count ?? 0) <= capacity.maximumMetadataBytes else {
            return RuntimeFailure(.capacityExceeded, message: "Supplier diagnostic exceeds runtime metadata capacity.", failedSupplierWorkUnavailable: failure.failedSupplierWorkUnavailable)
        }
        return failure
    }
    public func observe(_ operation: @Sendable (RuntimeAcceptedState) throws(RuntimeFailure) -> Void) throws(RuntimeFailure) {
        let accepted = try storage.withLock { (value: inout RuntimeSessionMetadata) throws(RuntimeFailure) in
            guard !value.closing, !value.closed else { throw RuntimeFailure(.closed, message: "Observation owner is closing/closed.", lastAccepted: value.accepted) }
            guard value.observers < capacity.maximumObservationLeases else { throw RuntimeFailure(.capacityExceeded, message: "Observation lease capacity exhausted.", lastAccepted: value.accepted) }
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

// Session creation/replacement owns the verified prefix and reserved workspace lifetime.
internal struct _RuntimeTrialAdmission: Sendable {
    let accepted: RuntimeAcceptedState
    let capacity: RuntimeCapacity
    fileprivate init(accepted: RuntimeAcceptedState, capacity: RuntimeCapacity) {
        self.accepted = accepted; self.capacity = capacity
    }
}

// The checked-out session ticket alone owns reset and control binding authority.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct _RuntimeOperationAdmission: Sendable {
    let accepted: RuntimeAcceptedState
    let source: RuntimeCancellationSource
    fileprivate init(accepted: RuntimeAcceptedState, source: RuntimeCancellationSource) {
        self.accepted = accepted; self.source = source
    }
}

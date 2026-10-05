import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class SensorPipelineSession<BaseCheckpoints: RuntimeCheckpointHandling>: SensorPipelineOperating {
    private let runtime: RuntimeSession<SensorPipelineCheckpointHandler<BaseCheckpoints>>
    private let model: CompiledMechanicalModel
    public let definition: SensorPipelineDefinition
    public let configuration: RuntimeConfiguration
    private let engine: SensorPipelineEngine
    private let lifecycle: SensorPipelineLifecycle

    @inline(never)
    public init(model: CompiledMechanicalModel, configuration: RuntimeConfiguration, initialState: KinematicState,
                contributors: [RuntimeContributorState], seed: UInt64, definition: SensorPipelineDefinition,
                checkpoints: BaseCheckpoints, sources: any ObservationSourcePreparing = ReferenceObservationSourcePreparer(),
                onRelease: (@Sendable () -> Void)? = nil) throws(SensorPipelineFailure) {
        self.model = model; self.definition = definition; self.configuration = configuration
        engine = SensorPipelineEngine(definition: definition, capacity: configuration.capacity, sources: sources)
        let lifecycleOwner = SensorPipelineLifecycle(maximumReaders: configuration.capacity.maximumObservationLeases, onRelease: onRelease)
        lifecycle = lifecycleOwner
        var enteredRuntime = false
        do throws(SensorPipelineFailure) {
            // FIXME(INCOMPLETE_IMPLEMENTATION): No typed event-boundary pipeline adapter is admitted.
            // Source initialization refuses registered event history until pre/post authority and replay are qualified.
            guard !configuration.requiredContributors.contains(where: { $0.category == .event }), definition.eventContributorIDs.isEmpty else { throw .unsupportedDomain }
            guard configuration.requiredContributors.contains(definition.schema), !contributors.contains(where: { $0.id == definition.schemaID }),
                  definition.bounds.maximumBatchRows <= configuration.capacity.maximumBatchStates,
                  definition.bounds.maximumContributorBytes <= configuration.capacity.maximumContributorBytes else { throw .invalidDefinition }
            let state = try engine.initial(model: model, physical: initialState)
            let record = try engine.record(state)
            let handler = SensorPipelineCheckpointHandler(base: checkpoints, definition: definition, capacity: configuration.capacity)
            enteredRuntime = true
            do throws(RuntimeFailure) { runtime = try RuntimeSession(model: model, configuration: configuration, initialState: initialState,
                contributors: contributors + [record], seed: seed, checkpoints: handler, onRelease: { lifecycleOwner.runtimeDidRelease() }) }
            catch { throw .runtime(error) }
        } catch {
            if !enteredRuntime { lifecycleOwner.runtimeDidRelease() }
            throw error
        }
    }
    deinit { _ = shutdown() }
    public func snapshot() -> RuntimeAcceptedState { runtime.snapshot() }
    public func profile() -> RuntimeProfile { runtime.profile() }

    @inline(never)
    public func performTrial(_ operation: @Sendable (inout RuntimeTrial, inout RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        do { try lifecycle.acquireMutation() } catch { throw error.runtimeFailure.retaining(runtime.snapshot()) }
        defer { lifecycle.releaseMutation() }
        let accepted = runtime.snapshot()
        return try runtime.performTrial { (trial: inout RuntimeTrial, control: inout RuntimeStepControl) throws(RuntimeFailure) in
            let decision = try operation(&trial, &control)
            guard decision == .accept else { return decision }
            do throws(SensorPipelineFailure) { try self.stage(&trial, control: control, accepted: accepted) }
            catch {
                let failure = error.runtimeFailure
                throw RuntimeFailure(failure.code, contributor: self.definition.schemaID, message: failure.message,
                    failedSupplierWorkUnavailable: failure.failedSupplierWorkUnavailable)
            }
            return decision
        }
    }
    @inline(never)
    private func stage(_ trial: inout RuntimeTrial, control: RuntimeStepControl, accepted: RuntimeAcceptedState) throws(SensorPipelineFailure) {
        let record: RuntimeContributorState
        do { record = try trial.contributor(definition.schemaID) } catch { throw .runtime(error) }
        guard record == accepted.checkpoint.contributors.first(where: { $0.id == definition.schemaID }) else { throw .staleSource }
        var state = try engine.decode(record, model: model).state
        guard state.source.encoded == (try engine.binding(model: model, physical: accepted.physical.state,
            sequence: accepted.checkpoint.acceptedSteps)).encoded, accepted.checkpoint.acceptedSteps < UInt64.max else { throw .staleSource }
        let physical = try candidate(trial, accepted: accepted)
        try engine.advance(&state, model: model, physical: physical, sequence: accepted.checkpoint.acceptedSteps + 1, control: control)
        let replacement = try engine.record(state)
        do throws(RuntimeFailure) { try control.beginWorkBlock(units: 1); try trial.replaceContributor(replacement) }
        catch { throw .runtime(error) }
    }
    @inline(never)
    private func candidate(_ trial: RuntimeTrial, accepted: RuntimeAcceptedState) throws(SensorPipelineFailure) -> KinematicState {
        var q: [Double] = [], v: [Double] = [], a: [Double] = [], anchors: [PrescribedAnchorState] = []
        do throws(RuntimeFailure) {
            for i in accepted.physical.state.q.indices { q.append(try trial.position(at: i)) }
            for i in accepted.physical.state.v.indices { v.append(try trial.velocity(at: i)); a.append(try trial.acceleration(at: i)) }
            for sample in accepted.physical.state.prescribedAnchors { anchors.append(try trial.prescribedAnchor(sample.frame)) }
        } catch { throw .runtime(error) }
        do { return try KinematicState(revision: model.stamp.revision, time: trial.timeSeconds, q: q, v: v, acceleration: a, prescribedAnchors: anchors) }
        catch { throw .staleSource }
    }
    @inline(never)
    public func readBatch(_ request: SensorBatchReadRequest,
                          operation: @Sendable (SensorBatchLease) throws(SensorPipelineFailure) -> Void) throws(SensorPipelineFailure) {
        let epoch = try lifecycle.acquireRead()
        defer { lifecycle.releaseRead() }
        let result = Mutex<SensorPipelineFailure?>(nil)
        do throws(RuntimeFailure) {
            try runtime.observe { (accepted: RuntimeAcceptedState) throws(RuntimeFailure) in
                do throws(SensorPipelineFailure) {
                    let batch = try self.batch(request, accepted: accepted)
                    let lease = SensorBatchLease(batch: batch, epoch: epoch, lifecycle: self.lifecycle)
                    defer { lease.close() }
                    try operation(lease)
                } catch {
                    result.withLock { $0 = error }
                    throw error.runtimeFailure
                }
            }
        } catch {
            if let failure = result.withLock({ $0 }) { throw failure }
            throw .runtime(error)
        }
    }
    @inline(never)
    private func batch(_ request: SensorBatchReadRequest, accepted: RuntimeAcceptedState) throws(SensorPipelineFailure) -> SensorBatch {
        guard request.schema == definition.schemaID, request.version == definition.version, request.world == definition.world,
              request.model == model.stamp else { throw .incompatibleSchema }
        guard request.maximumRows <= definition.bounds.maximumBatchRows,
              request.maximumScalars <= definition.bounds.maximumBatchRows else { throw .capacityExceeded }
        guard let record = accepted.checkpoint.contributors.first(where: { $0.id == definition.schemaID }) else { throw .corruptState }
        let state = try engine.decode(record, model: model).state
        guard state.source.encoded == (try engine.binding(model: model, physical: accepted.physical.state, sequence: accepted.checkpoint.acceptedSteps)).encoded else { throw .staleSource }
        guard request.after >= state.floor else { throw .overrun(retainedAfter: state.floor) }
        guard request.after <= state.lastReady else { throw .invalidDefinition }
        var rows: [SensorRecord] = []; rows.reserveCapacity(min(request.maximumRows, request.maximumScalars))
        for row in state.ready where row.readySequence > request.after {
            guard rows.count < request.maximumRows, rows.count < request.maximumScalars else { break }
            rows.append(row)
        }
        return SensorBatch(definition: definition, model: model.stamp, records: rows, floor: state.floor, last: state.lastReady)
    }
    public func observe(_ operation: @Sendable (RuntimeAcceptedState) throws(RuntimeFailure) -> Void) throws(RuntimeFailure) {
        try runtime.observe(operation)
    }
    public func restart(_ bytes: [UInt8], codec: any RuntimeCheckpointCoding) throws(RuntimeFailure) -> RuntimeAcceptedState {
        do { try lifecycle.acquireMutation() } catch { throw error.runtimeFailure.retaining(runtime.snapshot()) }
        defer { lifecycle.releaseMutation() }
        let restored = try runtime.restart(bytes, codec: codec)
        do { try lifecycle.advancedEpoch() } catch { throw error.runtimeFailure.retaining(restored) }
        return restored
    }
    public func checkpoint(codec: any RuntimeCheckpointCoding) throws(RuntimeFailure) -> [UInt8] { try runtime.checkpoint(codec: codec) }
    // FIXME(INCOMPLETE_IMPLEMENTATION): No sensor model/schema migration mapping is admitted.
    // Existing RuntimeModelReplacing callers receive typed refusal; mapped state and cold-replay proof are required before success.
    public func replaceModel(_ request: RuntimeModelReplacement) throws(RuntimeFailure) -> RuntimeAcceptedState {
        throw RuntimeFailure(.unsupportedDomain, contributor: definition.schemaID, message: "Sensor owner model replacement is unsupported.", lastAccepted: runtime.snapshot())
    }
    public func cancel() { runtime.cancel() }
    @discardableResult public func shutdown() -> RuntimeShutdownStatus {
        lifecycle.close(); let status = runtime.shutdown(); return status == .closed && lifecycle.hasReaders ? .draining : status
    }
    public func shutdownStatus() -> RuntimeShutdownStatus? {
        let status = runtime.shutdownStatus(); return status == .closed && lifecycle.hasReaders ? .draining : status
    }
}

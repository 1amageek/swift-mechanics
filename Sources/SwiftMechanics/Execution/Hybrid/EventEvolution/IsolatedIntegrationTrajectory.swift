
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct IsolatedIntegrationTrajectory<Checkpoints: RuntimeCheckpointHandling>: HybridTrajectoryQuerying {
    public let model: CompiledMechanicalModel
    public let equations: any SmoothODEEquations
    public let continuation: IntegrationContinuationProvider
    public let configuration: RuntimeConfiguration
    private let checkpoints: Checkpoints
    private let integrator: any ExplicitIntegrating
    private let codec: any RuntimeCheckpointCoding
    public init(model: CompiledMechanicalModel, equations: any SmoothODEEquations, continuation: IntegrationContinuationProvider,
                configuration: RuntimeConfiguration, checkpoints: Checkpoints, integrator: any ExplicitIntegrating,
                codec: any RuntimeCheckpointCoding = NativeRuntimeCheckpointCodec()) throws(HybridError) {
        guard equations.descriptor == continuation.descriptor, equations.descriptor.model == model.stamp,
              configuration.requiredContributors.contains(continuation.schema) else { throw .invalidInput }
        do { try equations.validate(model:model) } catch { throw .runtime(error) }
        self.model=model; self.equations=equations; self.continuation=continuation; self.configuration=configuration
        self.checkpoints=checkpoints; self.integrator=integrator; self.codec=codec
    }
    @inline(never)
    public func query(from source: RuntimeCheckpoint, to time: Double, cancellation: HybridCancellation) throws(HybridError) -> HybridTrajectoryResult {
        let sourceOwner=HybridCheckpointOwner(source)
        let owner=try preparedOwner(source:sourceOwner,to:time,cancellation:cancellation)
        defer { owner.shutdown() }
        return try validateResult(integrateOwner(owner,to:time),source:sourceOwner,to:time,cancellation:cancellation)
    }
    @inline(never)
    private func preparedOwner(source: HybridCheckpointOwner, to time: Double,
                               cancellation: HybridCancellation) throws(HybridError) -> RuntimeSession<Checkpoints> {
        try cancellation.check()
        guard source.checkpoint.model == model.stamp, source.checkpoint.continuation == configuration.continuation,
              time.isFinite, time >= source.checkpoint.physical.time else { throw .staleModel }
        let owner: RuntimeSession<Checkpoints>
        do { owner=try createOwner(source.checkpoint) } catch { throw .runtime(error) }
        do throws(RuntimeFailure) { try restartOwner(owner,source:source.checkpoint) }
        catch { owner.shutdown(); throw .runtime(error) }
        return owner
    }
    @inline(never)
    private func createOwner(_ source: RuntimeCheckpoint) throws(RuntimeFailure) -> RuntimeSession<Checkpoints> {
        try RuntimeSession(model:model,configuration:configuration,initialState:source.physical,
            contributors:source.contributors,seed:source.random.seed,checkpoints:checkpoints)
    }
    @inline(never)
    private func restartOwner(_ owner: RuntimeSession<Checkpoints>, source: RuntimeCheckpoint) throws(RuntimeFailure) {
        let bytes=try codec.encode(source,capacity:configuration.capacity)
        _=try owner.restart(bytes,codec:codec)
    }
    @inline(never)
    private func integrateOwner(_ owner: RuntimeSession<Checkpoints>, to time: Double) throws(HybridError) -> HybridIntegratedOutcome {
        do { return HybridIntegratedOutcome(try integrator.advance(owner,model:model,equations:equations,continuation:continuation,to:time)) }
        catch { throw .trajectory(error) }
    }
    @inline(never)
    private func validateResult(_ outcome: HybridIntegratedOutcome, source: HybridCheckpointOwner, to time: Double,
                                cancellation: HybridCancellation) throws(HybridError) -> HybridTrajectoryResult {
        try cancellation.check()
        let result=outcome.result
        let candidate=result.accepted.checkpoint
        let source=source.checkpoint
        guard candidate.physical.time == time, candidate.model == source.model,
              candidate.continuation == source.continuation, candidate.random == source.random else {
            // FIXME(INCOMPLETE_IMPLEMENTATION): Stateful/RNG-changing smooth equations reach isolated trajectory queries.
            // Exact transfer of all required state and random continuation must be implemented before admission.
            throw .unsupportedDomain
        }
        for record in source.contributors where record.id != continuation.schema.id {
            guard candidate.contributors.first(where: { $0.id == record.id }) == record else { throw .unsupportedDomain }
        }
        guard candidate.contributors.count == source.contributors.count else { throw .invalidContinuation }
        return HybridTrajectoryResult(checkpoint:candidate,work:result.work)
    }
}

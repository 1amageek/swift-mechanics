
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferencePlanarTrialOperator: PlanarTrialOperating, Sendable {
    public let codec: any PlanarContinuationCoding
    public let flow: any PlanarFlowOperating
    public init(codec: any PlanarContinuationCoding, flow: any PlanarFlowOperating) { self.codec = codec; self.flow = flow }
    @inline(never)
    public func advance(model: CompiledMechanicalModel, source: PlanarSource, duration: Double, policy: PlanarPolicy,
                        trial: inout RuntimeTrial, control: inout RuntimeStepControl,
                        numerical: inout NumericalWork, continuation: inout PlanarContinuationWork) throws(RuntimeFailure) -> PlanarStepResult {
        try control.beginWorkBlock(units: 1)
        let record = try trial.contributor(codec.schema.id)
        let state: PlanarState
        do throws(PlanarContinuationError) {
            try PlanarCarrierAdmission.validate(model, codec: codec, work: &continuation)
            state = try codec.decode(record, work: &continuation)
        } catch { throw planarContinuationFailure(error, id: codec.schema.id) }
        guard state.time == trial.timeSeconds else {
            throw RuntimeFailure(.invalidState, contributor: codec.schema.id, message: "Planar field and trial physical times differ.")
        }
        guard duration.isFinite, duration > 0, duration <= state.grid.limits.maximumStep, state.sequence < UInt64.max,
              (state.time+duration).isFinite, state.time+duration > state.time else {
            throw RuntimeFailure(.invalidContributor, contributor: codec.schema.id, message: "Planar history/time domain cannot advance.")
        }
        try control.beginWorkBlock(units: 1)
        let result: PlanarStepResult
        do throws(PlanarContinuationError) {
            result = try PlanarFlowInvocation.invoke(flow: flow, state: state, source: source,
                duration: duration, policy: policy, work: &numerical).result
        } catch { throw planarContinuationFailure(error, id: codec.schema.id) }
        try control.beginWorkBlock(units: 1)
        guard result.state.grid == state.grid, result.state.source == source,
              result.state.time == state.time+duration, result.state.sequence == state.sequence+1 else {
            throw RuntimeFailure(.invalidState, contributor: codec.schema.id, message: "Planar supplier must preserve binding and advance exactly once.")
        }
        let next: RuntimeContributorState
        do throws(PlanarContinuationError) {
            next = try codec.encode(result.state, work: &continuation)
            guard !policy.isCancelled() else { throw .cancelled }
            try continuation.poll()
        } catch { throw planarContinuationFailure(error, id: codec.schema.id) }
        try control.beginWorkBlock(units: 1)
        try trial.replaceContributor(next)
        try trial.setTime(result.state.time)
        return result
    }
}

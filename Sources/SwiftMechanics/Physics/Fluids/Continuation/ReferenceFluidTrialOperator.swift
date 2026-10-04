@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct ReferenceFluidTrialOperator: FluidTrialOperating, Sendable {
    public let codec: any FluidContinuationCoding
    public let evolution: any FluidEvolving
    public init(codec: any FluidContinuationCoding,evolution: any FluidEvolving) { self.codec=codec; self.evolution=evolution }
    public func advance(model: CompiledMechanicalModel, boundary: FluidBoundary, duration: Double,
                        policy: FluidPolicy, trial: inout RuntimeTrial, control: inout RuntimeStepControl,
                        numerical: inout NumericalWork, bytes: inout FluidByteWork) throws(RuntimeFailure) -> FluidEvolution {
        try control.beginWorkBlock(units:1)
        guard model.stamp == codec.channel.model,model.descriptor.worldFrame == codec.channel.frame,
              model.descriptor.rootBase == .fixed,model.descriptor.rootAuthority == .fixed,
              model.descriptor.initialState.q.isEmpty,model.descriptor.initialState.v.isEmpty else {
            throw RuntimeFailure(.incompatibleModel,contributor:codec.schema.id,message:"Fluid trial carrier binding is incompatible.")
        }
        let record=try trial.contributor(codec.schema.id)
        let state:FluidState
        do throws(FluidError) { state=try codec.decode(record,work:&bytes) }
        catch { throw fluidRuntimeFailure(error,id:codec.schema.id) }
        guard state.time == trial.timeSeconds else { throw RuntimeFailure(.invalidState,contributor:codec.schema.id,message:"Fluid history time must equal physical trial time.") }
        guard duration.isFinite,duration > 0,duration <= state.channel.limits.maximumStep,
              state.sequence < UInt64.max,state.time+duration > state.time,(state.time+duration).isFinite else {
            throw RuntimeFailure(.invalidContributor,contributor:codec.schema.id,message:"Fluid trial duration/history domain is inadmissible.")
        }
        try control.beginWorkBlock(units:1)
        let result:FluidEvolution
        do throws(FluidError) { result=try evolution.step(state:state,boundary:boundary,duration:duration,policy:policy,work:&numerical) }
        catch { throw fluidRuntimeFailure(error,id:codec.schema.id) }
        try control.beginWorkBlock(units:1)
        guard state.sequence < UInt64.max, duration.isFinite, duration > 0,
              result.state.channel == state.channel,result.state.boundary == boundary,
              result.state.time == state.time+duration,result.state.time > state.time,
              result.state.sequence == state.sequence+1 else {
            throw RuntimeFailure(.invalidState,contributor:codec.schema.id,message:"Fluid supplier did not advance the admitted history/time exactly once.")
        }
        let next:RuntimeContributorState
        do throws(FluidError) { next=try codec.encode(result.state,work:&bytes); try policy.poll() }
        catch { throw fluidRuntimeFailure(error,id:codec.schema.id) }
        try control.beginWorkBlock(units:1)
        try trial.replaceContributor(next); try trial.setTime(result.state.time)
        return result
    }
}

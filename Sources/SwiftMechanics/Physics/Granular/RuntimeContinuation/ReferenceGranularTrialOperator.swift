@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct ReferenceGranularTrialOperator: GranularRuntimeTrialOperating, Sendable {
    public let journal: GranularRuntimeJournal
    public let evolution: any GranularEvolving
    public init(journal: GranularRuntimeJournal, evolution: any GranularEvolving = ReferenceGranularEvolution()) {
        self.journal=journal;self.evolution=evolution
    }
    @inline(never)
    public func advance(model: CompiledMechanicalModel, duration: Double, trial: inout RuntimeTrial,
                        control: inout RuntimeStepControl, work: inout GranularRuntimeWork) throws(RuntimeFailure) -> GranularStepResult {
        try control.beginWorkBlock(units:1)
        let prior=work.safePoint,point=control
        work.safePoint={ () throws(RuntimeFailure) in try point.beginWorkBlock(units:0) }
        defer { work.safePoint=prior }
        let record=try trial.contributor(journal.schema.id),accepted: GranularRuntimeContinuation
        do throws(GranularRuntimeError) {
            try GranularRuntimeCarrier.validate(model,source:journal.source,work:&work)
            accepted=try journal.decode(record,work:&work)
        } catch { throw error.runtimeFailure(journal.schema.id) }
        guard duration.bitPattern == journal.source.timeStepSeconds.bitPattern,
              accepted.particles.timeSeconds.bitPattern == trial.timeSeconds.bitPattern,
              accepted.gravityChoiceIndices.count < journal.source.maximumAcceptedSteps else {
            throw RuntimeFailure(.invalidState,contributor:journal.schema.id,message:"Granular duration/time/step authority cannot advance this trial.")
        }
        try control.beginWorkBlock(units:1)
        var random=accepted.random
        let expected=try random.next(),actual=try trial.nextRandom()
        guard actual == expected else { throw RuntimeFailure(.invalidState,contributor:journal.schema.id,message:"Trial RNG differs from accepted granular continuation.") }
        let choice=actual % UInt64(journal.source.gravityChoices.count),result: GranularStepResult
        do throws(GranularRuntimeError) {
            var workspace=GranularWorkspace()
            result=try journal.step(accepted.particles,choice:choice,workspace:&workspace,work:&work)
            try GranularRuntimeInvocation.compare(evolution:evolution,accepted:accepted.particles,canonical:result,
                source:journal.source,choice:choice,work:&work)
        } catch { throw error.runtimeFailure(journal.schema.id) }
        try control.beginWorkBlock(units:1)
        let next: RuntimeContributorState
        do throws(GranularRuntimeError) {
            var choices=accepted.gravityChoiceIndices;choices.append(choice)
            let continuation=GranularRuntimeContinuation(source:journal.source,particles:result.state,random:random,choices:choices)
            next=try journal.encode(continuation,work:&work)
        } catch { throw error.runtimeFailure(journal.schema.id) }
        try control.beginWorkBlock(units:1)
        try trial.replaceContributor(next);try trial.setTime(result.state.timeSeconds)
        return result
    }
}

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
        let accepted=try load(model:model,trial:&trial,work:&work)
        guard duration.bitPattern == journal.source.timeStepSeconds.bitPattern,
              accepted.particles.timeSeconds.bitPattern == trial.timeSeconds.bitPattern,
              accepted.gravityChoiceIndices.count < journal.source.maximumAcceptedSteps else {
            throw RuntimeFailure(.invalidState,contributor:journal.schema.id,message:"Granular duration/time/step authority cannot advance this trial.")
        }
        try control.beginWorkBlock(units:1)
        let input=try draw(accepted,trial:&trial)
        let evidence=try canonical(input,work:&work)
        do throws(GranularRuntimeError) {
            try GranularRuntimeInvocation.compare(evolution:evolution,input:input,canonical:evidence,source:journal.source,work:&work)
        } catch { throw error.runtimeFailure(journal.schema.id) }
        try control.beginWorkBlock(units:1)
        let next=try encode(input,evidence:evidence,work:&work)
        try control.beginWorkBlock(units:1)
        try trial.replaceContributor(next);try trial.setTime(evidence.result.state.timeSeconds)
        return evidence.result
    }
    @inline(never)
    private func load(model: CompiledMechanicalModel,trial: inout RuntimeTrial,
                      work: inout GranularRuntimeWork) throws(RuntimeFailure) -> GranularRuntimeContinuation {
        let record=try trial.contributor(journal.schema.id)
        do throws(GranularRuntimeError) {
            try GranularRuntimeCarrier.validate(model,source:journal.source,work:&work)
            return try journal.decode(record,work:&work)
        } catch { throw error.runtimeFailure(journal.schema.id) }
    }
    @inline(never)
    private func draw(_ accepted: GranularRuntimeContinuation,trial: inout RuntimeTrial) throws(RuntimeFailure) -> GranularRuntimeStepInput {
        var random=accepted.random
        let expected=try random.next(),actual=try trial.nextRandom()
        guard actual == expected else { throw RuntimeFailure(.invalidState,contributor:journal.schema.id,message:"Trial RNG differs from accepted granular continuation.") }
        return GranularRuntimeStepInput(accepted:accepted,random:random,choice:actual % UInt64(journal.source.gravityChoices.count))
    }
    @inline(never)
    private func canonical(_ input: GranularRuntimeStepInput,work: inout GranularRuntimeWork) throws(RuntimeFailure) -> GranularRuntimeStepEvidence {
        do throws(GranularRuntimeError) {
            var workspace=GranularWorkspace()
            return GranularRuntimeStepEvidence(try journal.step(input.accepted.particles,choice:input.choice,workspace:&workspace,work:&work))
        } catch { throw error.runtimeFailure(journal.schema.id) }
    }
    @inline(never)
    private func encode(_ input: GranularRuntimeStepInput,evidence: GranularRuntimeStepEvidence,
                        work: inout GranularRuntimeWork) throws(RuntimeFailure) -> RuntimeContributorState {
        do throws(GranularRuntimeError) {
            var choices=input.accepted.gravityChoiceIndices;choices.append(input.choice)
            let continuation=GranularRuntimeContinuation(source:journal.source,particles:evidence.result.state,random:input.random,choices:choices)
            return try journal.encode(continuation,work:&work)
        } catch { throw error.runtimeFailure(journal.schema.id) }
    }
}

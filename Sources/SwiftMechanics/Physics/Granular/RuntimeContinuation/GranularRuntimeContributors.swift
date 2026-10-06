@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct GranularRuntimeContributors: RuntimeContributorHandling, Sendable {
    public let journal: GranularRuntimeJournal
    private let expected: RuntimeCheckpoint?
    private let cancellation: RuntimeCancellationSource?
    public init(journal: GranularRuntimeJournal) { self.journal=journal;expected=nil;cancellation=nil }
    internal init(journal: GranularRuntimeJournal,checkpoint: RuntimeCheckpoint,cancellation: RuntimeCancellationSource?) {
        self.journal=journal;expected=checkpoint;self.cancellation=cancellation
    }
    public var schemas: [RuntimeContributorSchema] { [journal.schema] }
    @inline(never)
    public func validate(_ record: RuntimeContributorState,model: CompiledMechanicalModel,
                         budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        var work=try makeWork(budget)
        do throws(GranularRuntimeError) {
            try GranularRuntimeCarrier.validate(model,source:journal.source,work:&work)
            let continuation=try journal.decode(record,work:&work)
            try accept(continuation,recordID:record.id,work:&work)
        } catch { throw error.runtimeFailure(journal.schema.id) }
        return try RuntimeValidationEvidence(workUnitsUsed:work.workUnits,scratchBytesUsed:work.peakBytes)
    }
    @inline(never)
    private func makeWork(_ budget: RuntimeValidationBudget) throws(RuntimeFailure) -> GranularRuntimeWork {
        do throws(GranularRuntimeError) {
            var work=try GranularRuntimeWork(physics:journal.source.physicsBudget,maximumBytes:budget.scratchBytes,maximumWorkUnits:budget.workUnits)
            let source=cancellation
            work.safePoint={ () throws(RuntimeFailure) in try source?.check() }
            return work
        } catch { throw error.runtimeFailure(journal.schema.id) }
    }
    @inline(never)
    private func accept(_ continuation: GranularRuntimeContinuation,recordID: String,
                        work: inout GranularRuntimeWork) throws(GranularRuntimeError) {
        if let expected {
            try work.charge(8)
            guard expected.physical.time.bitPattern == continuation.particles.timeSeconds.bitPattern,
                  expected.acceptedSteps == continuation.particles.steps,expected.random == continuation.random else {
                throw .runtime(RuntimeFailure(.invalidState,contributor:recordID,message:"Whole checkpoint granular time/steps/RNG differ."))
            }
        }
        try journal.source.poll(work)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Runtime model replacement calls this requirement. Granular source/law/geometry migration and conservation are not implemented; a changed source must not publish a migrated journal before those original physical proofs exist.
    public func migrate(_ record: RuntimeContributorState,transition: ModelTransition,target: CompiledMechanicalModel,
                        budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.unsupportedDomain,contributor:journal.schema.id,message:"Granular journal admits only unchanged identified source continuation.")
    }
}

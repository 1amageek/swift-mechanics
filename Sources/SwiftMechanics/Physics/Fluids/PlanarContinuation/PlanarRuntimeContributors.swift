
public struct PlanarRuntimeContributors: RuntimeContributorHandling, Sendable {
    public let codec: any PlanarContinuationCoding
    private let expectedTime: Double?
    private let expectedSequence: UInt64?
    public init(codec: any PlanarContinuationCoding) {
        self.codec = codec; self.expectedTime = nil; self.expectedSequence = nil
    }
    internal init(codec: any PlanarContinuationCoding, time: Double, sequence: UInt64) {
        self.codec = codec; self.expectedTime = time; self.expectedSequence = sequence
    }
    public var schemas: [RuntimeContributorSchema] { [codec.schema] }
    @inline(never)
    public func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel,
                         budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        var work: PlanarContinuationWork
        do throws(PlanarContinuationError) {
            work = try PlanarContinuationWork(maximumStorageBytes: budget.scratchBytes, maximumWorkUnits: budget.workUnits)
            try PlanarCarrierAdmission.validate(model, codec: codec, work: &work)
            let state = try codec.decode(record, work: &work)
            try work.charge(2)
            if let time = expectedTime, let sequence = expectedSequence {
                guard state.time == time, state.sequence == sequence else { throw .runtime(.invalidState) }
            }
            try work.poll()
        } catch { throw planarContinuationFailure(error, id: record.id) }
        return try RuntimeValidationEvidence(workUnitsUsed: work.workUnits, scratchBytesUsed: work.peakStorageBytes)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Runtime model migration calls this requirement; moving-grid/material reconciliation is not implemented. Changed-context fields must not be published until physical conservation and explicit migration/reinitialization are proved.
    public func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel,
                        budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.unsupportedDomain, contributor: codec.schema.id, message: "Planar model/grid migration is outside same-context continuation.")
    }
}

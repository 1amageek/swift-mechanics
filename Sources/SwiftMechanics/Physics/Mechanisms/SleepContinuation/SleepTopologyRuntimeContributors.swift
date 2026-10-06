@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal struct SleepTopologyRuntimeContributors: RuntimeContributorHandling, Sendable {
    let owner:CheckpointedMechanismSleep
    let additional:any RuntimeContributorHandling
    let physical:KinematicState
    let sequence:UInt64
    let schemas:[RuntimeContributorSchema]
    init(owner:CheckpointedMechanismSleep,additional:any RuntimeContributorHandling,physical:KinematicState,
         sequence:UInt64,capacity:RuntimeCapacity) throws(RuntimeFailure) {
        let extra=additional.schemas
        guard owner.schemas.count <= capacity.maximumContributors,extra.count <= capacity.maximumContributors-owner.schemas.count else {
            throw RuntimeFailure(.capacityExceeded,message:"Sleep source registry count exceeds capacity.")
        }
        var union=owner.schemas,metadata=0
        for schema in extra {
            guard !union.contains(where:{$0.id == schema.id}),schema.maximumBytes <= capacity.maximumContributorBytes else {
                throw RuntimeFailure(.duplicateContributor,message:"Sleep source additional schema is duplicate or oversized.")
            }
            union.append(schema)
        }
        for schema in union {
            let (next,overflow)=metadata.addingReportingOverflow(schema.id.utf8.count)
            guard !overflow,next <= capacity.maximumMetadataBytes else { throw RuntimeFailure(.capacityExceeded,message:"Sleep source metadata exceeds capacity.") }
            metadata=next
        }
        self.owner=owner;self.additional=additional;self.physical=physical;self.sequence=sequence;schemas=union.sorted {$0.id < $1.id}
    }
    func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        if owner.schemas.contains(where:{$0.id == record.id}) {
            let provider=SleepRuntimeContributors(owner:owner,physical:physical,sequence:sequence)
            let count:Int,extra:Int
            do { count=try NumericalWork.sum(physical.q.count,physical.v.count);extra=try NumericalWork.sum(count,2) }
            catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Sleep source association count overflow.") }
            guard extra <= budget.workUnits else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Sleep source association work exhausted.") }
            let remainder=try RuntimeValidationBudget(workUnits:budget.workUnits-extra,scratchBytes:budget.scratchBytes)
            let evidence=try provider.validate(record,model:model,budget:remainder)
            let point:[Double],time:Double,steps:UInt64
            if record.id == owner.continuation.schema.id {
                let history=try owner.continuation.history(record);point=history.acceptedPoint;time=history.acceptedTime;steps=history.acceptedSteps
            } else {
                let history=try owner.history(record);point=history.position+history.velocity;time=history.acceptedTime;steps=history.acceptedSequence
            }
            guard time.bitPattern == physical.time.bitPattern,steps == sequence,point.count == physical.q.count+physical.v.count else {
                throw RuntimeFailure(.invalidContributor,message:"Sleep source history time or global sequence differs.")
            }
            for i in physical.q.indices { guard point[i].bitPattern == physical.q[i].bitPattern else { throw RuntimeFailure(.invalidContributor,message:"Sleep source position bits differ.") } }
            for i in physical.v.indices { guard point[physical.q.count+i].bitPattern == physical.v[i].bitPattern else { throw RuntimeFailure(.invalidContributor,message:"Sleep source velocity bits differ.") } }
            guard evidence.workUnitsUsed <= budget.workUnits-extra else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Sleep source association work exhausted.") }
            return try RuntimeValidationEvidence(workUnitsUsed:evidence.workUnitsUsed+extra,scratchBytesUsed:evidence.scratchBytesUsed)
        }
        return try additional.validate(record,model:model,budget:budget)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Record-only migration cannot retire original source law and sleep authority.
    // Full explicit topology preparation is required for successful target publication.
    func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.incompatibleMigration,message:"Complete sleep source migration requires explicit retirement.")
    }
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct SleepRuntimeContributors:RuntimeContributorHandling, Sendable {
    let owner:CheckpointedMechanismSleep
    let physical:KinematicState
    let sequence:UInt64
    var schemas:[RuntimeContributorSchema] { owner.schemas }
    func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard model.stamp == owner.model.stamp,model.descriptor == owner.model.descriptor,model.tree.layout == owner.model.tree.layout else {
            throw RuntimeFailure(.incompatibleModel,message:"Sleep checkpoint model authority differs.")
        }
        if record.id == owner.continuation.schema.id {
            let evidence=try owner.continuation.validate(record,model:model,budget:budget)
            let history=try owner.continuation.history(record)
            guard history.acceptedTime == physical.time,history.acceptedPoint == physical.q+physical.v else { throw RuntimeFailure(.invalidContributor,message:"Integration history differs from checkpoint physical/time chart.") }
            return evidence
        }
        guard record.bytes.count <= budget.workUnits,record.bytes.count <= budget.scratchBytes else {
            throw RuntimeFailure(.contributorBudgetExceeded,message:"Sleep decoding exceeds work/scratch capacity.")
        }
        let history=try owner.associated(record,physical:physical,sequence:sequence)
        var work:NumericalWork
        do { work=NumericalWork(budget:try NumericalBudget(scalarStorage:(budget.scratchBytes-record.bytes.count)/8,
            arithmeticOperations:budget.workUnits-record.bytes.count,iterations:budget.workUnits-record.bytes.count)) }
        catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Sleep proof budget cannot be formed.") }
        if history.asleep.contains(true) {
            guard physical.acceleration.allSatisfy({$0 == 0}),let proof=try owner.restCertificate(physical:physical,drive:history.drive,work:&work) else {
                throw RuntimeFailure(.invalidContributor,message:"Sleeping checkpoint has no actual stationary equilibrium proof.")
            }
            for group in proof.groups {
                guard let first=group.first,group.allSatisfy({history.asleep[$0] == history.asleep[first] && history.restSince[$0] == history.restSince[first]}) else {
                    throw RuntimeFailure(.invalidContributor,message:"Connected sleep flags/rest history differ.")
                }
            }
        }
        let used:Int,scratch:Int
        do { used=try NumericalWork.sum(record.bytes.count,work.operations);scratch=try NumericalWork.sum(record.bytes.count,try NumericalWork.product(8,work.peakScalarStorage)) }
        catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Sleep validation evidence overflow.") }
        return try RuntimeValidationEvidence(workUnitsUsed:used,scratchBytesUsed:scratch)
    }
    func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        try owner.migrate(record,transition:transition,target:target,budget:budget)
    }
}

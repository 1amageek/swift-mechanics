@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class ConstrainedSleepEventContinuation: IslandEndpointContributing, Sendable {
    public let catalog:HybridEventCatalog
    public let policy:HybridEvolutionPolicy
    public let schema:RuntimeContributorSchema
    public var schemas:[RuntimeContributorSchema] { [schema] }
    public let program:StationaryIslandProgram
    private let signature:[UInt8]
    public init(environment:any ConstrainedSleepEventEnvironment,policy:HybridEvolutionPolicy,maximumRecordBytes:Int? = nil) throws(RuntimeFailure) {
        let bound=environment.evolutionPolicy
        guard policy.maximumEvents == bound.maximumEvents,policy.maximumQueries == bound.maximumQueries,policy.maximumRootIterations == bound.maximumRootIterations,policy.maximumCatalogEvents == bound.maximumCatalogEvents,policy.maximumContinuationBytes == bound.maximumContinuationBytes,policy.timeTolerance.bitPattern == bound.timeTolerance.bitPattern,policy.minimumEventSpacing.bitPattern == bound.minimumEventSpacing.bitPattern,
              environment.catalog.eventIDs.count == 1,environment.catalog.model == environment.program.source.stamp else { throw RuntimeFailure(.invalidContributor,message:"Event continuation bound environment/policy differs.") }
        let cap=maximumRecordBytes ?? policy.maximumContinuationBytes
        let n=environment.program.source.tree.layout.velocityCount,m=environment.program.islands.count
        let bytes=try ConstrainedSleepBytes.sum(environment.catalog.providerSignature.count,try ConstrainedSleepBytes.product(8,try ConstrainedSleepBytes.sum(9,try ConstrainedSleepBytes.sum(try ConstrainedSleepBytes.product(2,n),m))))
        guard bytes <= cap,bytes <= policy.maximumContinuationBytes else { throw RuntimeFailure(.capacityExceeded,message:"Constrained event fixed record exceeds declared capacity.") }
        signature=environment.catalog.providerSignature;catalog=environment.catalog;program=environment.program;self.policy=policy
        schema=try RuntimeContributorSchema(id:"mechanics.hybrid.constrained-sleep.v1",category:.event,version:1,maximumBytes:bytes)
    }
    public func initialRecord(physical:KinematicState,acceptedSequence:UInt64 = 0) throws(RuntimeFailure) -> RuntimeContributorState {
        try record(ConstrainedSleepEventHistory(time:physical.time,sequence:acceptedSequence,q:physical.q,v:physical.v))
    }
    @inline(never)
    public func recordEndpoint(source:RuntimeCheckpoint,physical:KinematicState,acceptedSequence:UInt64,work:inout NumericalWork) throws(RuntimeFailure) -> RuntimeContributorState {
        try charge(&work)
        // The lower private query creates a real sequence-zero bootstrap before restoring the full original checkpoint.
        if acceptedSequence == 0 { return try initialRecord(physical:physical) }
        guard source.acceptedSteps < UInt64.max,acceptedSequence == source.acceptedSteps+1,let old=source.contributors.first(where:{$0.id == schema.id}) else { throw RuntimeFailure(.invalidContributor,message:"Event endpoint lacks original global history.") }
        let h=try associated(old,physical:source.physical,sequence:source.acceptedSteps)
        return try record(ConstrainedSleepEventHistory(time:physical.time,sequence:acceptedSequence,q:physical.q,v:physical.v,count:h.impactCount,lastTime:h.lastImpactTime,eventID:h.lastEventID,source:h.sourceSequence,target:h.targetSequence,wake:h.wakeIslandIDs))
    }
    @inline(never)
    internal func impactRecord(source:RuntimeCheckpoint,wake:PreparedIslandImpactWake,work:inout NumericalWork) throws(RuntimeFailure) -> RuntimeContributorState {
        guard source == wake.source,source.acceptedSteps < UInt64.max,wake.physical.time > source.physical.time,catalog.eventIDs == [wake.eventID],let old=source.contributors.first(where:{$0.id == schema.id}) else { throw RuntimeFailure(.invalidContributor,message:"Event wake original whole source differs.") }
        let h=try associated(old,physical:source.physical,sequence:source.acceptedSteps)
        guard h.impactCount < UInt64(policy.maximumEvents),h.impactCount == 0 || wake.physical.time-h.lastImpactTime >= policy.minimumEventSpacing else { throw RuntimeFailure(.capacityExceeded,message:"Event count/spacing admission failed.") }
        try charge(&work)
        return try record(ConstrainedSleepEventHistory(time:wake.physical.time,sequence:source.acceptedSteps+1,q:wake.physical.q,v:wake.physical.v,count:h.impactCount+1,lastTime:wake.physical.time,eventID:wake.eventID,source:source.acceptedSteps,target:source.acceptedSteps+1,wake:wake.affectedIslandIDs))
    }
    private func charge(_ work:inout NumericalWork) throws(RuntimeFailure) {
        do throws(NumericalError) { try work.requireStorage(schema.maximumBytes);try work.chargeOperations(schema.maximumBytes) }
        catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Constrained event encoding exhausted.") }
    }
    @inline(never)
    private func record(_ h:ConstrainedSleepEventHistory) throws(RuntimeFailure) -> RuntimeContributorState {
        try valid(h);var bytes=signature;bytes.reserveCapacity(schema.maximumBytes)
        for word in [h.acceptedTime.bitPattern,h.acceptedSequence,UInt64(h.position.count),UInt64(program.islands.count),h.impactCount,h.lastImpactTime.bitPattern,h.lastEventID,h.sourceSequence,h.targetSequence] { ConstrainedSleepBytes.put(word,into:&bytes) }
        for array in [h.position,h.velocity] { for x in array { ConstrainedSleepBytes.put(x.bitPattern,into:&bytes) } }
        for island in program.islands { ConstrainedSleepBytes.put(h.wakeIslandIDs.contains(island.id) ? 1 : 0,into:&bytes) }
        guard bytes.count == schema.maximumBytes else { throw RuntimeFailure(.invalidContributor,message:"Constrained event fixed encoding differs.") }
        return try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:bytes)
    }
    @inline(never)
    public func history(_ record:RuntimeContributorState) throws(RuntimeFailure) -> ConstrainedSleepEventHistory {
        guard record.id == schema.id,record.category == schema.category,record.version == schema.version,record.bytes.count == schema.maximumBytes,record.bytes.starts(with:signature) else { throw RuntimeFailure(.invalidContributor,message:"Constrained event physical/catalog/policy signature differs.") }
        var offset=signature.count
        let time=Double(bitPattern:try ConstrainedSleepBytes.take(record.bytes,at:&offset)),s=try ConstrainedSleepBytes.take(record.bytes,at:&offset),n=try ConstrainedSleepBytes.take(record.bytes,at:&offset),m=try ConstrainedSleepBytes.take(record.bytes,at:&offset),count=try ConstrainedSleepBytes.take(record.bytes,at:&offset),last=Double(bitPattern:try ConstrainedSleepBytes.take(record.bytes,at:&offset)),event=try ConstrainedSleepBytes.take(record.bytes,at:&offset),source=try ConstrainedSleepBytes.take(record.bytes,at:&offset),target=try ConstrainedSleepBytes.take(record.bytes,at:&offset)
        guard n == UInt64(program.source.tree.layout.velocityCount),m == UInt64(program.islands.count) else { throw RuntimeFailure(.invalidContributor,message:"Event counts differ.") }
        var q:[Double]=[],v:[Double]=[],wake:[UInt64]=[];q.reserveCapacity(Int(n));v.reserveCapacity(Int(n));wake.reserveCapacity(Int(m))
        for _ in 0..<Int(n) { q.append(Double(bitPattern:try ConstrainedSleepBytes.take(record.bytes,at:&offset))) }
        for _ in 0..<Int(n) { v.append(Double(bitPattern:try ConstrainedSleepBytes.take(record.bytes,at:&offset))) }
        for island in program.islands { let flag=try ConstrainedSleepBytes.take(record.bytes,at:&offset);guard flag<=1 else { throw RuntimeFailure(.invalidContributor,message:"Malformed event wake flag.") };if flag == 1 { wake.append(island.id) } }
        guard offset == record.bytes.count else { throw RuntimeFailure(.invalidContributor,message:"Event trailing bytes.") }
        let h=ConstrainedSleepEventHistory(time:time,sequence:s,q:q,v:v,count:count,lastTime:last,eventID:event,source:source,target:target,wake:wake);try valid(h);return h
    }
    private func valid(_ h:ConstrainedSleepEventHistory) throws(RuntimeFailure) {
        guard h.position.count == program.source.tree.layout.positionCount,h.velocity.count == program.source.tree.layout.velocityCount,h.position.allSatisfy({$0.isFinite}),h.velocity.allSatisfy({$0.isFinite}),h.acceptedTime.isFinite,h.lastImpactTime.isFinite,h.acceptedTime >= program.constraints.minimumTime,h.acceptedTime <= program.constraints.maximumTime,h.impactCount <= UInt64(policy.maximumEvents),h.wakeIslandIDs.count <= program.islands.count,Set(h.wakeIslandIDs).count == h.wakeIslandIDs.count,h.wakeIslandIDs.allSatisfy({id in program.islands.contains(where:{$0.id == id})}) else { throw RuntimeFailure(.invalidContributor,message:"Malformed constrained event history.") }
        if h.impactCount == 0 { guard h.lastEventID == 0,h.sourceSequence == 0,h.targetSequence == 0,h.wakeIslandIDs.isEmpty else { throw RuntimeFailure(.invalidContributor,message:"Empty event history has impact identity.") } }
        else { guard catalog.eventIDs.contains(h.lastEventID),h.sourceSequence < UInt64.max,h.targetSequence == h.sourceSequence+1,h.targetSequence <= h.acceptedSequence,h.lastImpactTime <= h.acceptedTime,!h.wakeIslandIDs.isEmpty else { throw RuntimeFailure(.invalidContributor,message:"Accepted event source/target/identity differs.") } }
    }
    internal func associated(_ record:RuntimeContributorState,physical:KinematicState,sequence:UInt64) throws(RuntimeFailure) -> ConstrainedSleepEventHistory {
        let h=try history(record)
        guard physical.revision == catalog.model.revision,h.acceptedTime.bitPattern == physical.time.bitPattern,h.acceptedSequence == sequence,ConstrainedSleepBytes.equal(h.position,physical.q),ConstrainedSleepBytes.equal(h.velocity,physical.v) else { throw RuntimeFailure(.invalidContributor,message:"Event actual q/v/time/global sequence differs.") };return h
    }
    public func validateAssociation(record:RuntimeContributorState,physical:KinematicState,acceptedSequence:UInt64,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard schema.maximumBytes <= budget.workUnits,schema.maximumBytes <= budget.scratchBytes else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Event contextual validation capacity exceeded.") }
        _=try associated(record,physical:physical,sequence:acceptedSequence)
        return try RuntimeValidationEvidence(workUnitsUsed:schema.maximumBytes,scratchBytesUsed:schema.maximumBytes)
    }
    public func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard model.stamp == program.source.stamp,model.descriptor == program.source.descriptor,model.policy == program.source.policy,model.tree.layout == program.source.tree.layout,schema.maximumBytes <= budget.workUnits,schema.maximumBytes <= budget.scratchBytes else { throw RuntimeFailure(.invalidContributor,message:"Event original model/validation bounds differ.") }
        _=try history(record);return try RuntimeValidationEvidence(workUnitsUsed:schema.maximumBytes,scratchBytesUsed:schema.maximumBytes)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): No selected mapped geometry/law/event topology migration authority exists. Real accepted topology must prove a new catalog and contextual history before this callable path succeeds.
    public func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState { throw RuntimeFailure(.incompatibleMigration,message:"Constrained event topology migration unsupported.") }
}

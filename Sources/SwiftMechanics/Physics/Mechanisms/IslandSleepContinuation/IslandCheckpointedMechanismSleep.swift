@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class IslandCheckpointedMechanismSleep: IslandMechanismSleepContinuing, Sendable {
    public let program:StationaryIslandProgram
    public var model:CompiledMechanicalModel { program.source }
    public let dynamics:any StationaryIslandComputing
    public let policy:MechanismSleepContinuationPolicy
    public let operationPolicy:IslandSleepOperationPolicy
    public let participant:(any IslandEndpointContributing)?
    internal let participantSchema:RuntimeContributorSchema?
    public let descriptor:ODEDescriptor
    public let continuation:IntegrationContinuationProvider
    public let schema:RuntimeContributorSchema
    public var schemas:[RuntimeContributorSchema] { continuation.schemas+[schema]+(participantSchema.map { [$0] } ?? []) }
    internal let memo:IslandSleepProofCache
    private let signature:[UInt8]
    public init(identity:String,program:StationaryIslandProgram,dynamics:any StationaryIslandComputing = ReferenceStationaryIslandDynamics(),policy:MechanismSleepContinuationPolicy,integration:ExplicitIntegrationPolicy,operationPolicy:IslandSleepOperationPolicy,participant:(any IslandEndpointContributing)? = nil) throws(RuntimeFailure) {
        let n=program.source.tree.layout.velocityCount,m=program.islands.count
        guard n <= policy.thresholds.maximumCoordinates,n > 0,m > 0,program.source.tree.layout.positionCount == n,
              (participant?.schemas.count ?? 1) == 1 else { throw RuntimeFailure(.unsupportedDomain,message:"Mixed sleep requires bounded scalar islands and one optional endpoint schema.") }
        let participantSchemas=participant?.schemas ?? []
        guard participantSchemas.count <= 1,participantSchemas.allSatisfy({$0.id.utf8.count <= policy.maximumIdentityBytes && $0.maximumBytes <= operationPolicy.maximumRecordBytes}) else { throw RuntimeFailure(.capacityExceeded,message:"Endpoint participant identity/record capacity exceeded.") }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Arbitrary stateful/controller/random participants have no pure-query replay authority. Only one explicit nonphysical event-history participant is admitted until those actual state/RNG contracts are implemented.
        guard participantSchemas.allSatisfy({$0.category == .event}) else { throw RuntimeFailure(.unsupportedDomain,message:"Mixed pure query accepts only a bound event-history participant.") }
        participantSchema=participantSchemas.first
        var signature=program.binding
        for value in [policy.thresholds.kineticEnergyThreshold,policy.thresholds.normalizedVelocityThreshold,policy.minimumRestDuration] { IslandSleepBits.put(value.bitPattern,into:&signature) }
        for count in [policy.maximumIdentityBytes,operationPolicy.maximumSupplierInvocations,operationPolicy.maximumQueries,operationPolicy.maximumQuerySteps,operationPolicy.maximumRecordBytes,integration.budget.maximumAttempts,integration.budget.maximumAcceptedSteps,integration.budget.maximumOuterArithmetic,integration.budget.supplier.scalarStorage,integration.budget.supplier.arithmeticOperations,integration.budget.supplier.iterations,integration.maximumContinuationBytes] { IslandSleepBits.put(UInt64(count),into:&signature) }
        if let s=participantSchema { IslandSleepBits.put(UInt64(s.id.utf8.count),into:&signature);signature.append(contentsOf:s.id.utf8);IslandSleepBits.put(UInt64(s.category.rawValue),into:&signature);IslandSleepBits.put(UInt64(s.version),into:&signature);IslandSleepBits.put(UInt64(s.maximumBytes),into:&signature) }
        let chartBytes=try IslandSleepBits.product(2,signature.count)
        guard chartBytes <= policy.maximumIdentityBytes else { throw RuntimeFailure(.capacityExceeded,message:"Exact physical/law chart exceeds identity capacity.") }
        let digits=Array("0123456789abcdef".utf8);var hex:[UInt8]=[];hex.reserveCapacity(chartBytes)
        for byte in signature { hex.append(digits[Int(byte >> 4)]);hex.append(digits[Int(byte & 15)]) }
        let dimensions=program.constraints.layout.dimensions+program.constraints.layout.dimensions.map { PhysicalDimension(length:$0.length,time:-1,angle:$0.angle) }
        descriptor=try ODEDescriptor(identity:identity,chart:String(decoding:hex,as:UTF8.self),model:program.source.stamp,dimensions:dimensions,maximumIdentityBytes:policy.maximumIdentityBytes,maximumCoordinates:integration.budget.maximumCoordinates)
        continuation=try IntegrationContinuationProvider(descriptor:descriptor,policy:integration)
        let bytes=try IslandSleepBits.sum(signature.count,try IslandSleepBits.product(8,try IslandSleepBits.sum(8,try IslandSleepBits.sum(try IslandSleepBits.product(2,n),try IslandSleepBits.product(4,m)))))
        guard bytes <= operationPolicy.maximumRecordBytes else { throw RuntimeFailure(.capacityExceeded,message:"Island sleep history capacity exceeded.") }
        schema=try RuntimeContributorSchema(id:"mechanics.mechanism.island-sleep.v1",category:.event,version:1,maximumBytes:bytes)
        self.program=program;self.dynamics=dynamics;self.policy=policy;self.operationPolicy=operationPolicy;self.participant=participant;self.signature=signature;memo=IslandSleepProofCache(count:m)
        guard Set(schemas.map { $0.id }).count == schemas.count else { throw RuntimeFailure(.duplicateContributor,message:"Island sleep endpoint schema collides.") }
    }
    public func initialRecord(physical:KinematicState,acceptedSequence:UInt64 = 0) throws(RuntimeFailure) -> RuntimeContributorState {
        try checkPhysical(physical)
        return try record(IslandSleepHistory(time:physical.time,sequence:acceptedSequence,q:physical.q,v:physical.v,ids:program.islands.map { $0.id },asleep:[Bool](repeating:false,count:program.islands.count),since:[Double](repeating:physical.time,count:program.islands.count),affected:[Bool](repeating:false,count:program.islands.count)))
    }
    public func initialIntegrationRecord(physical:KinematicState,acceptedSequence:UInt64 = 0) throws(RuntimeFailure) -> RuntimeContributorState {
        try checkPhysical(physical)
        return try continuation.record(acceptedTime:physical.time,point:physical.q+physical.v,nextStep:continuation.policy.initialStep,acceptedSteps:acceptedSequence,normalizedError:continuation.policy.method == .classicalRK4 || acceptedSequence == 0 ? nil : 0)
    }
    internal func checkParticipant() throws(RuntimeFailure) { guard participant?.schemas == participantSchema.map({[$0]}) else { throw RuntimeFailure(.invalidContributor,message:"Endpoint participant changed its bound schema.") } }
    internal func sameModel(_ model:CompiledMechanicalModel) -> Bool { model.stamp == self.model.stamp && model.descriptor == self.model.descriptor && model.policy == self.model.policy && model.tree.layout == self.model.tree.layout }
    internal func samePhysical(_ x:KinematicState,_ y:KinematicState) -> Bool { x.revision == y.revision && x.time.bitPattern == y.time.bitPattern && IslandSleepBits.equal(x.q,y.q) && IslandSleepBits.equal(x.v,y.v) && IslandSleepBits.equal(x.acceleration,y.acceleration) && x.prescribedAnchors == y.prescribedAnchors }
    internal func checkPhysical(_ p:KinematicState) throws(RuntimeFailure) {
        let n=model.tree.layout.velocityCount
        guard p.revision == model.stamp.revision,p.q.count == n,p.v.count == n,p.acceleration.count == n,p.prescribedAnchors.isEmpty,p.time.isFinite,p.time >= program.constraints.minimumTime,p.time <= program.constraints.maximumTime else { throw RuntimeFailure(.invalidState,message:"Island physical revision/shape/time/anchor authority differs.") }
        for i in 0..<n { guard p.q[i].isFinite,p.v[i].isFinite,p.acceleration[i].isFinite,p.q[i] >= program.constraints.minimumPosition[i],p.q[i] <= program.constraints.maximumPosition[i] else { throw RuntimeFailure(.invalidState,message:"Island physical source exceeds admitted domain.") } }
    }
    internal func check() throws(RuntimeFailure) {
        guard !Task.isCancelled,!policy.thresholds.isCancelled(),!program.policy.mechanics.isCancelled(),!program.policy.admission.isCancelled() else { throw RuntimeFailure(.cancelled,message:"Island sleep cancelled.") }
    }
    internal func record(_ h:IslandSleepHistory) throws(RuntimeFailure) -> RuntimeContributorState {
        try valid(h);var bytes=signature;bytes.reserveCapacity(schema.maximumBytes)
        for word in [h.acceptedTime.bitPattern,h.acceptedSequence,UInt64(h.position.count),UInt64(h.islandIDs.count),h.wakeSequence,h.lastWakeTime.bitPattern,h.lastWakeEventID,h.lastWakeKind] { IslandSleepBits.put(word,into:&bytes) }
        for values in [h.position,h.velocity,h.restSince] { for value in values { IslandSleepBits.put(value.bitPattern,into:&bytes) } }
        for id in h.islandIDs { IslandSleepBits.put(id,into:&bytes) }
        for flags in [h.asleep,h.lastWakeIslands] { for flag in flags { IslandSleepBits.put(flag ? 1 : 0,into:&bytes) } }
        guard bytes.count == schema.maximumBytes else { throw RuntimeFailure(.invalidContributor,message:"Island record layout differs.") }
        return try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:bytes)
    }
    public func history(_ record:RuntimeContributorState) throws(RuntimeFailure) -> IslandSleepHistory {
        guard record.id == schema.id,record.category == schema.category,record.version == schema.version,record.bytes.count == schema.maximumBytes,record.bytes.starts(with:signature) else { throw RuntimeFailure(.invalidContributor,message:"Island physical/program/policy signature differs.") }
        var offset=signature.count
        let time=Double(bitPattern:try IslandSleepBits.take(record.bytes,at:&offset)),sequence=try IslandSleepBits.take(record.bytes,at:&offset),n=try IslandSleepBits.take(record.bytes,at:&offset),m=try IslandSleepBits.take(record.bytes,at:&offset),wake=try IslandSleepBits.take(record.bytes,at:&offset),wakeTime=Double(bitPattern:try IslandSleepBits.take(record.bytes,at:&offset)),event=try IslandSleepBits.take(record.bytes,at:&offset),kind=try IslandSleepBits.take(record.bytes,at:&offset)
        guard n == UInt64(model.tree.layout.velocityCount),m == UInt64(program.islands.count) else { throw RuntimeFailure(.invalidContributor,message:"Island history counts differ.") }
        var arrays:[[Double]]=[]
        for count in [Int(n),Int(n),Int(m)] { var values:[Double]=[];values.reserveCapacity(count);for _ in 0..<count { values.append(Double(bitPattern:try IslandSleepBits.take(record.bytes,at:&offset))) };arrays.append(values) }
        var ids:[UInt64]=[];for _ in 0..<Int(m) { ids.append(try IslandSleepBits.take(record.bytes,at:&offset)) }
        var flags:[[Bool]]=[]
        for _ in 0..<2 { var values:[Bool]=[];for _ in 0..<Int(m) { let flag=try IslandSleepBits.take(record.bytes,at:&offset);guard flag <= 1 else { throw RuntimeFailure(.invalidContributor,message:"Malformed island flag.") };values.append(flag == 1) };flags.append(values) }
        guard offset == record.bytes.count else { throw RuntimeFailure(.invalidContributor,message:"Trailing island bytes.") }
        let h=IslandSleepHistory(time:time,sequence:sequence,q:arrays[0],v:arrays[1],ids:ids,asleep:flags[0],since:arrays[2],wakeSequence:wake,wakeTime:wakeTime,eventID:event,kind:kind,affected:flags[1]);try valid(h);return h
    }
    private func valid(_ h:IslandSleepHistory) throws(RuntimeFailure) {
        let n=model.tree.layout.velocityCount,m=program.islands.count
        guard h.position.count == n,h.velocity.count == n,h.islandIDs == program.islands.map({$0.id}),h.asleep.count == m,h.restSince.count == m,h.lastWakeIslands.count == m,
              h.acceptedTime.isFinite,h.lastWakeTime.isFinite,h.lastWakeKind <= 1,h.wakeSequence <= h.acceptedSequence,
              h.acceptedTime >= program.constraints.minimumTime,h.acceptedTime <= program.constraints.maximumTime,
              h.position.allSatisfy({$0.isFinite}),h.velocity.allSatisfy({$0.isFinite}),h.restSince.allSatisfy({$0.isFinite && $0 <= h.acceptedTime}),
              (h.lastWakeKind == 0 ? h.wakeSequence == 0 && h.lastWakeEventID == 0 && !h.lastWakeIslands.contains(true) : h.wakeSequence > 0 && h.lastWakeEventID > 0 && h.lastWakeTime <= h.acceptedTime && h.lastWakeIslands.contains(true)) else { throw RuntimeFailure(.invalidContributor,message:"Island history fields are malformed.") }
        for j in 0..<m where h.asleep[j] {
            guard h.acceptedTime-h.restSince[j] >= policy.minimumRestDuration,program.islands[j].sourceCoordinateIndices.allSatisfy({h.velocity[$0] == 0}) else { throw RuntimeFailure(.invalidContributor,message:"Sleeping island has no accepted dwell/zero velocity.") }
        }
    }
    internal func associated(_ record:RuntimeContributorState,physical:KinematicState,sequence:UInt64) throws(RuntimeFailure) -> IslandSleepHistory {
        try checkPhysical(physical);let h=try history(record)
        guard h.acceptedTime.bitPattern == physical.time.bitPattern,h.acceptedSequence == sequence,IslandSleepBits.equal(h.position,physical.q),IslandSleepBits.equal(h.velocity,physical.v) else { throw RuntimeFailure(.invalidContributor,message:"Whole island history q/v/time/global sequence differs.") };return h
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Record-only admission cannot prove mixed physical force, equilibrium or global history. Runtime sessions must use IslandSleepCheckpointHandler before accepting these records.
    public func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence { throw RuntimeFailure(.unsupportedDomain,message:"Mixed sleep requires contextual whole checkpoint admission.") }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Generic topology migration has no new structural-island/law/sleep authority. The explicit accepted topology event owner must prove mapped law and histories before success.
    public func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState { throw RuntimeFailure(.incompatibleMigration,message:"Mixed sleep topology migration is unsupported.") }
}

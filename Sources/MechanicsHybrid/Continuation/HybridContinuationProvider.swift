import MechanicsCompiler
import MechanicsJoints
import MechanicsRuntime

public struct HybridContinuationProvider: RuntimeContributorHandling, Sendable {
    public let catalog: HybridEventCatalog
    public let policy: HybridEvolutionPolicy
    public let impactPolicy: HybridPolicy
    public let schema: RuntimeContributorSchema
    private let signature: [UInt8]
    private let qCount: Int
    private let vCount: Int
    public var schemas: [RuntimeContributorSchema] { [schema] }
    public init(catalog: HybridEventCatalog, policy: HybridEvolutionPolicy, impactPolicy: HybridPolicy,
                model: CompiledMechanicalModel) throws(RuntimeFailure) {
        guard catalog.model == model.stamp else { throw RuntimeFailure(.incompatibleModel,message:"Hybrid catalog model differs.") }
        qCount=model.tree.layout.positionCount; vCount=model.tree.layout.velocityCount
        guard catalog.eventIDs.count <= policy.maximumCatalogEvents else { throw RuntimeFailure(.capacityExceeded,message:"Hybrid signature count exceeds capacity.") }
        let preflight=try HybridByteBounds.recordCapacity(identity:model.stamp.identity,providerBytes:catalog.providerSignature.count,
            events:catalog.eventIDs.count,q:qCount,v:vCount,scales:impactPolicy.impulseScales.count,maximum:policy.maximumContinuationBytes)
        guard impactPolicy.impulseScales.count == vCount else { throw RuntimeFailure(.invalidInput,message:"Hybrid impulse scales differ from the velocity layout.") }
        var data=HybridPayload(); data.bytes.reserveCapacity(preflight.total-preflight.recordBytes); data.put(UInt64(preflight.identityBytes)); data.bytes.append(contentsOf:model.stamp.identity.utf8)
        data.put(model.stamp.revision); data.put(catalog.geometryRevision); data.put(UInt64(catalog.providerSignature.count)); data.bytes.append(contentsOf:catalog.providerSignature)
        data.put(UInt64(catalog.eventIDs.count)); for id in catalog.eventIDs { data.put(id) }
        data.put(UInt64(qCount)); data.put(UInt64(vCount))
        for value in [policy.timeTolerance,policy.minimumEventSpacing,impactPolicy.lengthTolerance,impactPolicy.normalTolerance,impactPolicy.speedTolerance,
                      impactPolicy.independenceTolerance,impactPolicy.momentumAbsolute,impactPolicy.momentumRelative,impactPolicy.energyAbsolute,impactPolicy.energyRelative] { data.put(value) }
        for scale in impactPolicy.impulseScales { data.put(scale) }
        guard data.bytes.count == preflight.total-preflight.recordBytes else { throw RuntimeFailure(.invalidOwnerAccess,message:"Hybrid signature differs from its checked byte preflight.") }
        signature=data.bytes; self.catalog=catalog; self.policy=policy; self.impactPolicy=impactPolicy
        schema=try RuntimeContributorSchema(id:"mechanics.hybrid.events.v1",category:.event,version:1,maximumBytes:preflight.total)
    }
    public func initialRecord(physical: KinematicState) throws(RuntimeFailure) -> RuntimeContributorState {
        try record(physical:physical,previous:nil,eventIDs:[])
    }
    public func record(physical: KinematicState, previous: HybridHistory?, eventIDs: [UInt64]) throws(RuntimeFailure) -> RuntimeContributorState {
        guard physical.revision == catalog.model.revision, physical.q.count == qCount, physical.v.count == vCount else { throw RuntimeFailure(.invalidContributor,message:"Hybrid state/catalog layout differs.") }
        try validIDs(eventIDs)
        if let previous {
            guard previous.binding == signature else { throw RuntimeFailure(.incompatibleContinuation,message:"Previous hybrid history belongs to another model/geometry/provider/policy.") }
            try validIDs(previous.lastEventIDs)
            guard previous.acceptedPosition.count == qCount, previous.acceptedVelocity.count == vCount,
                  previous.acceptedPosition.allSatisfy({ $0.isFinite }), previous.acceptedVelocity.allSatisfy({ $0.isFinite }),
                  previous.acceptedTime.isFinite, previous.lastImpactTime.map({ $0.isFinite && $0 <= previous.acceptedTime }) ?? true,
                  (previous.impactGroups == 0 ? previous.lastImpactTime == nil && previous.lastEventIDs.isEmpty : previous.lastImpactTime != nil && !previous.lastEventIDs.isEmpty) else {
                throw RuntimeFailure(.invalidContributor,message:"Previous hybrid carry-forward fields are invalid.")
            }
        }
        let isImpact = !eventIDs.isEmpty
        let groups=previous?.impactGroups ?? 0
        guard !isImpact || groups < UInt64.max, previous.map({ physical.time >= $0.acceptedTime }) ?? true else { throw RuntimeFailure(.invalidContributor,message:"Hybrid history time/sequence invalid.") }
        let lastTime=isImpact ? physical.time : previous?.lastImpactTime
        let ids=isImpact ? eventIDs : previous?.lastEventIDs ?? []
        var data=HybridPayload(bytes:signature); data.bytes.reserveCapacity(schema.maximumBytes); data.put(physical.time); data.put(groups+(isImpact ? 1 : 0)); data.put(UInt64(lastTime == nil ? 0 : 1))
        if let lastTime { data.put(lastTime) }; data.put(UInt64(ids.count)); for id in ids { data.put(id) }
        for value in physical.q { data.put(value) }; for value in physical.v { data.put(value) }
        guard data.bytes.count <= schema.maximumBytes else { throw RuntimeFailure(.capacityExceeded,message:"Hybrid record exceeds schema capacity.") }
        return try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:data.bytes)
    }
    public func history(_ record: RuntimeContributorState) throws(RuntimeFailure) -> HybridHistory {
        guard record.id == schema.id, record.category == schema.category, record.version == schema.version,
              record.bytes.count <= schema.maximumBytes else { throw RuntimeFailure(.invalidContributor,message:"Hybrid schema mismatch.") }
        var data=HybridPayload(bytes:record.bytes); try data.expect(signature)
        let time=try data.scalar(), groups=try data.get(), flag=try data.get()
        guard flag <= 1 else { throw RuntimeFailure(.invalidContributor,message:"Hybrid time flag invalid.") }
        let last: Double? = flag == 1 ? try data.scalar() : nil
        let count=try data.get(); guard count <= UInt64(catalog.eventIDs.count) else { throw RuntimeFailure(.invalidContributor,message:"Hybrid event count invalid.") }
        var ids: [UInt64]=[]; for _ in 0..<Int(count) { ids.append(try data.get()) }
        try validIDs(ids)
        guard (groups == 0 ? last == nil && ids.isEmpty : last != nil && !ids.isEmpty), last.map({ $0 <= time }) ?? true else { throw RuntimeFailure(.invalidContributor,message:"Hybrid event ordering/time/sequence invalid.") }
        var q: [Double]=[],v: [Double]=[]; q.reserveCapacity(qCount); v.reserveCapacity(vCount)
        for _ in 0..<qCount { q.append(try data.scalar()) }; for _ in 0..<vCount { v.append(try data.scalar()) }
        guard data.cursor == data.bytes.count else { throw RuntimeFailure(.invalidContributor,message:"Trailing hybrid continuation bytes.") }
        return HybridHistory(binding:signature,time:time,q:q,v:v,groups:groups,lastTime:last,ids:ids)
    }
    private func validIDs(_ ids: [UInt64]) throws(RuntimeFailure) {
        guard ids.count <= catalog.eventIDs.count else { throw RuntimeFailure(.invalidContributor,message:"Hybrid carried event count exceeds catalog.") }
        for i in ids.indices {
            guard catalog.eventIDs.contains(ids[i]), i == 0 || ids[i-1] < ids[i] else { throw RuntimeFailure(.invalidContributor,message:"Hybrid event IDs must be known, unique and sorted.") }
        }
    }
    public func associatedHistory(_ record: RuntimeContributorState, physical: KinematicState) throws(RuntimeFailure) -> HybridHistory {
        let value=try history(record)
        guard physical.revision == catalog.model.revision, value.acceptedTime == physical.time,
              value.acceptedPosition == physical.q, value.acceptedVelocity == physical.v else { throw RuntimeFailure(.invalidContributor,message:"Hybrid continuation differs from accepted physical time/q/v.") }
        return value
    }
    public func validate(_ record: RuntimeContributorState, model: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard model.stamp == catalog.model else { throw RuntimeFailure(.incompatibleModel,message:"Hybrid model revision differs.") }
        var scratchBounds=HybridByteBounds(maximum:policy.maximumContinuationBytes)
        try scratchBounds.words(qCount); try scratchBounds.words(vCount); try scratchBounds.words(vCount); try scratchBounds.words(catalog.eventIDs.count)
        let scratch=scratchBounds.bytes
        guard record.bytes.count <= budget.workUnits, scratch <= budget.scratchBytes else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Hybrid validation exceeds work/storage budget.") }
        _=try history(record)
        return try RuntimeValidationEvidence(workUnitsUsed:record.bytes.count,scratchBytesUsed:scratch)
    }
    public func migrate(_ record: RuntimeContributorState, transition: ModelTransition, target: CompiledMechanicalModel, budget: RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Model migration reaches geometry/chart-bound event continuation.
        // Exact target geometry/event configuration and physical association must be reinitialized before success.
        throw RuntimeFailure(.incompatibleMigration,message:"Hybrid event history requires explicit target reinitialization.")
    }
}

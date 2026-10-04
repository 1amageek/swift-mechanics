@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public final class TopologyHistoryContributor: RuntimeContributorHandling, Sendable {
    public let model: CompiledMechanicalModel
    public let catalog: TopologyEventCatalog
    public let policy: TopologyContinuationPolicy
    public let events: [TopologyAcceptedEvent]
    public let record: RuntimeContributorState
    public let schema: RuntimeContributorSchema
    public var schemas:[RuntimeContributorSchema] { [schema] }
    private let signature:[UInt8]

    /// Restores bounded history bytes against an explicit immutable catalog and compiled target.
    public init(model:CompiledMechanicalModel,catalog:TopologyEventCatalog,policy:TopologyContinuationPolicy,
                record:RuntimeContributorState?=nil) throws(TopologyReleaseFailure) {
        self.model=model;self.catalog=catalog;self.policy=policy
        signature=try Self.signature(catalog,policy:policy)
        do throws(RuntimeFailure) { schema=try RuntimeContributorSchema(id:"mechanics.mechanisms.topology.v1",category:.event,version:1,maximumBytes:policy.maximumBytes) }
        catch { throw .runtime(error) }
        if let record {
            guard record.id == schema.id,record.category == schema.category,record.version == schema.version else { throw .invalidInput }
            events=try Self.decode(record.bytes,signature:signature,catalog:catalog,policy:policy)
            self.record=record
        } else {
            events=[];self.record=try Self.encode([],signature:signature,schema:schema,policy:policy)
        }
        try Self.validate(events,model:model,catalog:catalog,policy:policy)
    }
    private init(model:CompiledMechanicalModel,previous:TopologyHistoryContributor,events:[TopologyAcceptedEvent]) throws(TopologyReleaseFailure) {
        self.model=model;catalog=previous.catalog;policy=previous.policy;signature=previous.signature;schema=previous.schema
        try Self.validate(events,model:model,catalog:catalog,policy:policy)
        self.events=events;record=try Self.encode(events,signature:signature,schema:schema,policy:policy)
    }
    public func appending(source:RuntimeAcceptedState,target:ReconciledSubtreeRelease,observation:TopologyReleaseObservation,
                          ruleID:UInt64) throws(TopologyReleaseFailure) -> TopologyHistoryContributor {
        guard !Task.isCancelled else { throw .cancelled }
        let release=target.release
        guard source.physical == release.source,source.checkpoint.physical == release.source.state,
              source.checkpoint.model == model.stamp,release.sourceModel.descriptor == model.descriptor,
              source.checkpoint.contributors.contains(record),observation.release === release,
              source.checkpoint.acceptedSteps < UInt64.max,events.count < policy.maximumEvents,
              let rule=catalog.rules.first(where: { $0.id == ruleID }),rule.joint == release.removedJoint,
              rule.connector == release.connector,rule.subtreeRoot == release.subtreeRoot,
              rule.metric == observation.metric,rule.threshold == observation.threshold,
              events.last.map({ $0.id < ruleID && $0.acceptedTime <= source.checkpoint.physical.time && $0.acceptedSequence < source.checkpoint.acceptedSteps+1 }) ?? true,
              !events.contains(where: { $0.rule.connector == release.removedJoint }) else { throw .staleSource }
        let event=TopologyAcceptedEvent(admission:_TopologyEventAdmission(rule:rule,source:model.stamp,target:release.target.stamp,
            time:source.checkpoint.physical.time,sequence:source.checkpoint.acceptedSteps+1,observed:observation.observed))
        return try TopologyHistoryContributor(model:release.target,previous:self,events:events+[event])
    }
    public func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard record == self.record,model.stamp == self.model.stamp,model.descriptor == self.model.descriptor else {
            throw RuntimeFailure(.invalidContributor,message:"Topology history or exact compiled target/catalog binding differs.")
        }
        guard record.bytes.count <= budget.workUnits else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Topology history exceeds validation work.") }
        return try RuntimeValidationEvidence(workUnitsUsed:record.bytes.count,scratchBytesUsed:0)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): Generic compiler migration lacks full accepted checkpoint and catalog disposition authority.
    // Only the explicit appending/preparing path may admit topology history into a new revision.
    public func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.incompatibleMigration,message:"Topology history requires explicit accepted-boundary catalog preparation.")
    }
    internal func associated(_ checkpoint:RuntimeCheckpoint) throws(RuntimeFailure) {
        guard checkpoint.model == model.stamp,checkpoint.contributors.contains(record),
              checkpoint.physical.time >= (events.last?.acceptedTime ?? catalog.initialTime),
              checkpoint.acceptedSteps >= (events.last?.acceptedSequence ?? catalog.initialSequence) else {
            throw RuntimeFailure(.invalidContributor,message:"Topology history is ahead of physical time/accepted sequence or absent.")
        }
    }
    private static func signature(_ catalog:TopologyEventCatalog,policy:TopologyContinuationPolicy) throws(TopologyReleaseFailure) -> [UInt8] {
        guard catalog.rules.count <= policy.maximumEvents else { throw .capacityExceeded }
        var data=try TopologyPayload(policy:policy)
        try data.put(1);try data.put(catalog.initialModel.identity);try data.put(catalog.initialModel.revision)
        try data.put(catalog.initialTime.bitPattern);try data.put(catalog.initialSequence);try data.put(UInt64(catalog.rules.count))
        for rule in catalog.rules {
            try data.put(rule.id);for text in [rule.joint.key,rule.connector.key,rule.parentAnchor.key,rule.childAnchor.key,rule.subtreeRoot.key] { try data.put(text) }
            try data.put(rule.metric.rawValue);try data.put(rule.threshold.bitPattern)
        }
        return data.bytes
    }
    private static func encode(_ events:[TopologyAcceptedEvent],signature:[UInt8],schema:RuntimeContributorSchema,
                               policy:TopologyContinuationPolicy) throws(TopologyReleaseFailure) -> RuntimeContributorState {
        var data=try TopologyPayload(bytes:signature,policy:policy);try data.put(UInt64(events.count))
        for event in events {
            for value in [event.id,event.source.revision,event.target.revision,event.acceptedTime.bitPattern,event.acceptedSequence,event.observed.bitPattern] { try data.put(value) }
        }
        do throws(RuntimeFailure) { return try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:data.bytes) }
        catch { throw .runtime(error) }
    }
    private static func decode(_ bytes:[UInt8],signature:[UInt8],catalog:TopologyEventCatalog,
                               policy:TopologyContinuationPolicy) throws(TopologyReleaseFailure) -> [TopologyAcceptedEvent] {
        var data=try TopologyPayload(bytes:bytes,policy:policy);try data.expect(signature)
        let count=try data.get();guard count <= UInt64(policy.maximumEvents),count <= UInt64(catalog.rules.count) else { throw .capacityExceeded }
        var events:[TopologyAcceptedEvent]=[];events.reserveCapacity(Int(count))
        for _ in 0..<Int(count) {
            let id=try data.get(),source=try data.get(),target=try data.get(),time=try data.get(),sequence=try data.get(),observed=try data.get()
            guard let rule=catalog.rules.first(where: { $0.id == id }) else { throw .staleSource }
            events.append(TopologyAcceptedEvent(admission:_TopologyEventAdmission(rule:rule,
                source:ModelStamp(identity:catalog.initialModel.identity,revision:source),target:ModelStamp(identity:catalog.initialModel.identity,revision:target),
                time:Double(bitPattern:time),sequence:sequence,observed:Double(bitPattern:observed))))
        }
        guard data.ended else { throw .invalidInput };return events
    }
    private static func validate(_ events:[TopologyAcceptedEvent],model:CompiledMechanicalModel,catalog:TopologyEventCatalog,
                                 policy:TopologyContinuationPolicy) throws(TopologyReleaseFailure) {
        guard events.count <= policy.maximumEvents,model.stamp == (events.last?.target ?? catalog.initialModel) else { throw .staleSource }
        var stamp=catalog.initialModel,time=catalog.initialTime,sequence=catalog.initialSequence
        for (index,event) in events.enumerated() {
            let rule=event.rule
            guard event.source == stamp,stamp.revision < UInt64.max,event.target.revision == stamp.revision+1,
                  event.target.identity == stamp.identity,event.acceptedTime.isFinite,event.acceptedTime >= time,
                  event.acceptedSequence > sequence,index == 0 || events[index-1].id < event.id,
                  event.observed.isFinite,catalog.rules.contains(rule),
                  (rule.metric == .explicitRelease ? event.observed == 0 : abs(event.observed) > rule.threshold),
                  !model.descriptor.joints.contains(where: { $0.record.id == rule.joint }),
                  let connector=model.descriptor.joints.first(where: { $0.record.id == rule.connector }),
                  connector.record.parentBody == model.descriptor.root,connector.record.childBody == rule.subtreeRoot,
                  connector.record.parentAnchor.frame == rule.parentAnchor,connector.record.childAnchor.frame == rule.childAnchor,
                  connector.record.parentAnchor.placement == .fixed(.identity),connector.record.childAnchor.placement == .fixed(.identity),
                  connector.record.manifold.kind == .sixDOF,connector.authority == .dynamicState else { throw .staleSource }
            stamp=event.target;time=event.acceptedTime;sequence=event.acceptedSequence
        }
    }
}

internal struct _TopologyEventAdmission: Sendable {
    let rule:TopologyReleaseRule;let source:ModelStamp;let target:ModelStamp;let time:Double;let sequence:UInt64;let observed:Double
    fileprivate init(rule:TopologyReleaseRule,source:ModelStamp,target:ModelStamp,time:Double,sequence:UInt64,observed:Double) {
        self.rule=rule;self.source=source;self.target=target;self.time=time;self.sequence=sequence;self.observed=observed
    }
}

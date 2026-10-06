/// Immutable accepted topology wake, reconstructed against original owner-issued law authority.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public final class SleepTopologyWakeContributor: RuntimeContributorHandling, Sendable {
    public let retirement:PreparedSleepTopologyRetirement
    public let transition:NonlinearReconciledSubtreeRelease
    public let event:TopologyAcceptedEvent
    public let policy:TopologyContinuationPolicy
    public let schema:RuntimeContributorSchema
    public let record:RuntimeContributorState
    public let isBootstrap:Bool
    public var schemas:[RuntimeContributorSchema] { [schema] }
    public init(retirement:PreparedSleepTopologyRetirement,transition:NonlinearReconciledSubtreeRelease,
        history:TopologyHistoryContributor,ruleID:UInt64,policy:TopologyContinuationPolicy,
        record:RuntimeContributorState? = nil,work:inout NumericalWork) throws(TopologyReleaseFailure) {
        guard !Task.isCancelled else { throw .cancelled }
        guard retirement.release === transition.release,let event=history.events.last,event.id == ruleID,
              history.model.descriptor == transition.release.target.descriptor,
              event.source == retirement.source.checkpoint.model,event.target == transition.release.target.stamp,
              retirement.source.checkpoint.acceptedSteps < UInt64.max,
              event.acceptedSequence == retirement.source.checkpoint.acceptedSteps+1,
              event.acceptedTime.bitPattern == retirement.source.checkpoint.physical.time.bitPattern,
              event.rule.joint == transition.release.removedJoint,event.rule.connector == transition.release.connector else { throw .staleSource }
        let bytes=try SleepTopologyWakeEncoding.encode(retirement:retirement,transition:transition,event:event,policy:policy,work:&work)
        let schema:RuntimeContributorSchema,canonical:RuntimeContributorState
        do throws(RuntimeFailure) {
            schema=try RuntimeContributorSchema(id:"mechanics.mechanisms.sleep-topology-wake.v1",category:.event,version:1,maximumBytes:bytes.count)
            canonical=try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:bytes)
        } catch { throw .runtime(error) }
        if let record { guard record == canonical else { throw .staleSource } }
        self.retirement=retirement;self.transition=transition;self.event=event;self.policy=policy;self.schema=schema;self.record=canonical;isBootstrap=false
    }
    public init(bootstrapFor wake:SleepTopologyWakeContributor,physical:CompiledKinematicState,
                work:inout NumericalWork) throws(TopologyReleaseFailure) {
        guard !wake.isBootstrap,physical.stamp == wake.transition.release.target.stamp,
              physical.state == wake.transition.physical else { throw .invalidInput }
        try TopologyArithmetic.charge(wake.record.bytes.count,&work)
        var bytes=wake.record.bytes
        guard bytes.count >= 8 else { throw .invalidInput }
        for i in 0..<8 { bytes[i]=0 }
        let record:RuntimeContributorState
        do throws(RuntimeFailure) { record=try RuntimeContributorState(id:wake.schema.id,category:wake.schema.category,version:wake.schema.version,bytes:bytes) }
        catch { throw .runtime(error) }
        retirement=wake.retirement;transition=wake.transition;event=wake.event;policy=wake.policy;schema=wake.schema;self.record=record;isBootstrap=true
    }
    public func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        guard model.stamp == transition.release.target.stamp,model.descriptor == transition.release.target.descriptor,
              model.tree.layout == transition.release.target.tree.layout,record == self.record else {
            throw RuntimeFailure(.invalidContributor,message:"Topology wake source/catalog/target or canonical bytes differ.")
        }
        guard record.bytes.count <= budget.workUnits else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Topology wake validation work exhausted.") }
        return try RuntimeValidationEvidence(workUnitsUsed:record.bytes.count,scratchBytesUsed:0)
    }
    // FIXME(INCOMPLETE_IMPLEMENTATION): A later topology change has no declared disposition for this retired law/event.
    // A new original-source retirement and event chain proof is required before migration can succeed.
    public func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,
                        budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        throw RuntimeFailure(.incompatibleMigration,message:"Topology wake event requires explicit later event disposition.")
    }
}

import MechanicsCompiler
import MechanicsRuntime
import MechanicsNumerics
import MechanicsJoints
import MechanicsModel

public final class MechanismBreakContributor: RuntimeContributorHandling, Sendable {
    public let schema:RuntimeContributorSchema
    public let event:MechanismBreakEvent
    public let record:RuntimeContributorState
    private let target:CompiledMechanicalModel
    public var schemas:[RuntimeContributorSchema] { [schema] }
    public init(event:MechanismBreakEvent,target:CompiledMechanicalModel,maximumBytes:Int) throws(MechanismError) {
        var count=72
        for text in [event.source.identity,event.target.identity,event.joint.key,event.connector.key] {
            count=try MechanismArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(count,8) }
            for _ in text.utf8 { guard count < maximumBytes else { throw .capacityExceeded };count+=1 }
        }
        guard count <= maximumBytes else { throw .capacityExceeded }
        guard target.stamp == event.target,target.descriptor.initialState.time == event.acceptedTime,
              !target.descriptor.joints.contains(where:{$0.record.id == event.joint}),
              target.descriptor.joints.contains(where:{$0.record.id == event.connector && $0.record.manifold.kind == .sixDOF}) else { throw .staleBinding }
        var bytes:[UInt8]=[];bytes.reserveCapacity(count)
        func put(_ value:UInt64) { for shift in stride(from:0,to:64,by:8) { bytes.append(UInt8(truncatingIfNeeded:value >> shift)) } }
        func text(_ value:String) { put(UInt64(value.utf8.count));bytes.append(contentsOf:value.utf8) }
        put(event.id);put(event.source.revision);put(event.target.revision);put(event.acceptedTime.bitPattern)
        put(event.metric.rawValue);put(event.observed.bitPattern);put(event.threshold.bitPattern);put(1);put(1)
        text(event.source.identity);text(event.target.identity);text(event.joint.key);text(event.connector.key)
        do throws(RuntimeFailure) {
            schema=try RuntimeContributorSchema(id:"mechanics.mechanisms.break.v1",category:.event,version:1,maximumBytes:count)
            record=try RuntimeContributorState(id:schema.id,category:schema.category,version:schema.version,bytes:bytes)
        } catch { throw .runtime(error) }
        self.event=event;self.target=target
    }
    public func validate(_ record:RuntimeContributorState,model:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeValidationEvidence {
        var charged=record.bytes.count
        for _ in record.id.utf8 {
            guard charged < budget.workUnits else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Break metadata exceeds validation work bound.") }
            charged+=1
        }
        guard charged <= budget.workUnits else { throw RuntimeFailure(.contributorBudgetExceeded,message:"Break record exceeds validation work bound.") }
        guard model.stamp == target.stamp,model.descriptor == target.descriptor,record == self.record else {
            throw RuntimeFailure(.invalidContributor,message:"Break event or actual target topology binding differs.")
        }
        return try RuntimeValidationEvidence(workUnitsUsed:charged,scratchBytesUsed:0)
    }
    public func migrate(_ record:RuntimeContributorState,transition:ModelTransition,target:CompiledMechanicalModel,budget:RuntimeValidationBudget) throws(RuntimeFailure) -> RuntimeContributorState {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Event records are bound to one accepted source/target topology. Further topology changes require an explicit bounded event history/mapping and replay proof, not silent event reuse.
        throw RuntimeFailure(.incompatibleMigration,message:"Break event requires explicit new topology history authority.")
    }
}

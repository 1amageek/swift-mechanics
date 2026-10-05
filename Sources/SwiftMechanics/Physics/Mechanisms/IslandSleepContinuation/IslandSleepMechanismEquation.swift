import Synchronization
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandSleepMechanismEquation: SmoothODEEquations,Sendable {
    let owner:IslandCheckpointedMechanismSleep
    let source:RuntimeAcceptedState
    let history:IslandSleepHistory
    let execution:IslandSleepExecution
    let currentSession:(any RuntimeSessionOperating)?
    let queryInitialSequence:UInt64?
    private let prepared=Mutex<IslandSleepPreparation?>(nil)
    var descriptor:ODEDescriptor { owner.descriptor }
    init(owner:IslandCheckpointedMechanismSleep,source:RuntimeAcceptedState,history:IslandSleepHistory,execution:IslandSleepExecution,currentSession:(any RuntimeSessionOperating)? = nil,queryInitialSequence:UInt64? = nil) { self.owner=owner;self.source=source;self.history=history;self.execution=execution;self.currentSession=currentSession;self.queryInitialSequence=queryInitialSequence }
    func validate(model:CompiledMechanicalModel) throws(RuntimeFailure) {
        guard owner.sameModel(model) else { throw RuntimeFailure(.incompatibleModel,message:"Mixed equation requires its actual compiled source owner.") };try owner.check()
    }
    func read(_ p:KinematicState,into point:inout [Double]) throws(RuntimeFailure) {
        try owner.checkPhysical(p);guard point.count == descriptor.dimensions.count else { throw RuntimeFailure(.invalidState,message:"Island chart shape differs.") }
        for i in p.q.indices { point[i]=p.q[i];point[p.q.count+i]=p.v[i] }
    }
    func read(_ trial:RuntimeTrial,into point:inout [Double]) throws(RuntimeFailure) {
        let n=owner.model.tree.layout.velocityCount;guard point.count == 2*n else { throw RuntimeFailure(.invalidState,message:"Island trial chart shape differs.") }
        for i in 0..<n { point[i]=try trial.position(at:i);point[n+i]=try trial.velocity(at:i) }
    }
    @inline(never)
    func prepare(trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1);try owner.check()
        let source=currentSession?.snapshot() ?? self.source
        if let initial=queryInitialSequence {
            guard source.checkpoint.acceptedSteps >= initial,source.checkpoint.acceptedSteps-initial < UInt64(owner.operationPolicy.maximumQuerySteps) else { throw RuntimeFailure(.capacityExceeded,message:"Actual private accepted-step capacity exhausted before supplier.") }
        }
        guard let record=source.checkpoint.contributors.first(where:{$0.id == owner.schema.id}) else { throw RuntimeFailure(.missingContributor,message:"Prepared private sleep history missing.") }
        let history=try owner.associated(record,physical:source.checkpoint.physical,sequence:source.checkpoint.acceptedSteps)
        guard try trial.contributor(owner.schema.id) == source.checkpoint.contributors.first(where:{$0.id == owner.schema.id}),trial.timeSeconds.bitPattern == history.acceptedTime.bitPattern else { throw RuntimeFailure(.invalidOwnerAccess,message:"Mixed preparation source history/time changed.") }
        for i in history.position.indices { try control.beginWorkBlock(units:1);guard try trial.position(at:i).bitPattern == history.position[i].bitPattern,try trial.velocity(at:i).bitPattern == history.velocity[i].bitPattern else { throw RuntimeFailure(.invalidOwnerAccess,message:"Mixed preparation source q/v changed.") } }
        for record in source.checkpoint.contributors { guard try trial.contributor(record.id) == record else { throw RuntimeFailure(.invalidOwnerAccess,message:"Actual preparation full source registry differs.") } }
        for i in history.velocity.indices { guard try trial.acceleration(at:i).bitPattern == source.checkpoint.physical.acceleration[i].bitPattern else { throw RuntimeFailure(.invalidOwnerAccess,message:"Actual preparation source acceleration differs.") } }
        let value=try prepareProofs(source:source,history:history,work:&work)
        prepared.withLock { $0=value }
    }
    @inline(never)
    private func prepareProofs(source:RuntimeAcceptedState,history:IslandSleepHistory,work:inout NumericalWork) throws(RuntimeFailure) -> IslandSleepPreparation {
        try execution.reserveOwned(owner.program.islands.count,integration:&work)
        var proofs:[StationaryIslandRestCertificate?]=[];proofs.reserveCapacity(owner.program.islands.count)
        for j in owner.program.islands.indices {
            let proof=try owner.proof(index:j,physical:source.checkpoint.physical,execution:execution,work:&work)
            guard !history.asleep[j] || proof != nil else { throw RuntimeFailure(.invalidContributor,message:"Mixed sleeping source lacks actual rest proof.") };proofs.append(proof)
        };return IslandSleepPreparation(source:source,history:history,proofs:proofs)
    }
    @inline(never)
    func derivative(time:Double,point:[Double],into output:inout [Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1);try owner.check()
        guard let proofs=prepared.withLock({$0}),output.count == point.count else { throw RuntimeFailure(.invalidState,message:"Mixed derivative has no operation-local preparation.") }
        try execution.reserveOwned(try IslandSleepBits.product(4,owner.model.tree.layout.velocityCount),integration:&work)
        let context=try physicalPoint(time:time,point:point,start:proofs.history.acceptedTime)
        let acceleration=try owner.acceleration(physical:context,flags:proofs.history.asleep,proofs:proofs.proofs,execution:execution,work:&work)
        let n=context.q.count
        do throws(NumericalError) { try work.requireStorage(2*n);try work.chargeOperations(2*n) }
        catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Mixed derivative mapping exceeds numerical budget.") }
        for i in 0..<n { try control.beginWorkBlock(units:1);output[i]=context.v[i];output[n+i]=acceleration[i] }
    }
    private func physicalPoint(time:Double,point:[Double],start:Double) throws(RuntimeFailure) -> KinematicState {
        let n=owner.model.tree.layout.velocityCount
        guard point.count == 2*n,time >= start else { throw RuntimeFailure(.invalidState,message:"Mixed stage shape/time differs.") }
        do throws(JointError) { return try KinematicState(revision:owner.model.stamp.revision,time:time,q:Array(point[..<n]),v:Array(point[n...]),acceleration:[Double](repeating:0,count:n)) }
        catch { throw RuntimeFailure(.invalidState,message:"Mixed stage physical construction refused.") }
    }
    @inline(never)
    func write(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial) throws(RuntimeFailure) {
        let n=owner.model.tree.layout.velocityCount
        guard point.count == 2*n,derivative.count == point.count,
              let prepared=prepared.withLock({$0}),point.allSatisfy({$0.isFinite}),derivative.allSatisfy({$0.isFinite}) else { throw RuntimeFailure(.invalidState,message:"Mixed endpoint publication is incomplete.") }
        let history=prepared.history
        guard history.acceptedSequence < UInt64.max else { throw RuntimeFailure(.integerOverflow,message:"Actual mixed sequence overflow.") }
        let physical:KinematicState
        do throws(JointError) { physical=try KinematicState(revision:owner.model.stamp.revision,time:time,q:Array(point[..<n]),v:Array(point[n...]),acceleration:Array(derivative[n...])) }
        catch { throw RuntimeFailure(.invalidState,message:"Mixed endpoint physical construction failed.") }
        try owner.checkPhysical(physical)
        let record=try encodeEndpoint(physical:physical,prepared:prepared)
        for i in 0..<n { try trial.setPosition(physical.q[i],at:i);try trial.setVelocity(physical.v[i],at:i);try trial.setAcceleration(physical.acceleration[i],at:i) }
        try trial.setTime(time);try trial.replaceContributor(record)
        if let participant=owner.participant {
            let record=try execution.encode { (work:inout NumericalWork) throws(RuntimeFailure) in
                try owner.checkParticipant();return try participant.recordEndpoint(source:prepared.source.checkpoint,physical:physical,acceptedSequence:history.acceptedSequence+1,work:&work)
            }
            try owner.checkParticipant()
            guard let schema=owner.participantSchema,record.id == schema.id,record.category == schema.category,record.version == schema.version,record.bytes.count <= schema.maximumBytes else { throw RuntimeFailure(.invalidContributor,message:"Endpoint participant changed declared schema.") }
            try trial.replaceContributor(record)
        }
    }
    @inline(never)
    private func encodeEndpoint(physical:KinematicState,prepared:IslandSleepPreparation) throws(RuntimeFailure) -> RuntimeContributorState {
        let history=prepared.history
        try execution.reserveEncoding(try IslandSleepBits.sum(owner.schema.maximumBytes,try IslandSleepBits.product(2,owner.program.islands.count)))
        var flags=[Bool](repeating:false,count:owner.program.islands.count),since=[Double](repeating:physical.time,count:flags.count)
        for j in flags.indices {
            let island=owner.program.islands[j]
            if let proof=prepared.proofs[j],island.sourceCoordinateIndices.indices.allSatisfy({k in let i=island.sourceCoordinateIndices[k];return proof.position[k].bitPattern == physical.q[i].bitPattern && physical.v[i] == 0 && physical.acceleration[i] == 0}) {
                since[j]=history.restSince[j];flags[j]=physical.time-since[j] >= owner.policy.minimumRestDuration
            }
        }
        let h=IslandSleepHistory(time:physical.time,sequence:history.acceptedSequence+1,q:physical.q,v:physical.v,ids:history.islandIDs,asleep:flags,since:since,wakeSequence:history.wakeSequence,wakeTime:history.lastWakeTime,eventID:history.lastWakeEventID,kind:history.lastWakeKind,affected:history.lastWakeIslands)
        return try execution.encode { (work:inout NumericalWork) throws(RuntimeFailure) in
            do throws(NumericalError) { try work.requireStorage(owner.schema.maximumBytes);try work.chargeOperations(owner.schema.maximumBytes) }
            catch { throw RuntimeFailure(.contributorBudgetExceeded,message:"Mixed sleep encoding exceeds separate receipt budget.") };return try owner.record(h)
        }
    }
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class LoadedSleepMechanismEquation:SmoothODEEquations, Sendable {
    let owner:LoadedCheckpointedMechanismSleep
    let source:RuntimeAcceptedState
    let history:LoadedMechanismSleepHistory
    let base:StationaryAffineMechanismEquation
    let execution:any StationaryLoadExecuting
    private let prepared=LoadedSleepProofStorage()
    var descriptor:ODEDescriptor { owner.descriptor }
    private var omitted:Bool { history.mechanics.asleep.allSatisfy({$0}) }
    init(owner:LoadedCheckpointedMechanismSleep,source:RuntimeAcceptedState,history:LoadedMechanismSleepHistory,execution:any StationaryLoadExecuting) throws(RuntimeFailure) {
        self.owner=owner;self.source=source;self.history=history;self.execution=execution
        base=try owner.equation(drive:history.mechanics.drive,selection:history.selection,execution:execution)
    }
    func validate(model:CompiledMechanicalModel) throws(RuntimeFailure) { try base.validate(model:model) }
    func read(_ physical:KinematicState,into point:inout [Double]) throws(RuntimeFailure) { try base.read(physical,into:&point) }
    func read(_ trial:RuntimeTrial,into point:inout [Double]) throws(RuntimeFailure) { try base.read(trial,into:&point) }
    @inline(never)
    func prepare(trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1);try owner.check()
        try validatePreparationSource(trial:&trial,control:control)
        try prepareRestProof(work:&work)
        if !omitted { try base.prepare(trial:&trial,work:&work,control:control) }
    }
    @inline(never)
    private func validatePreparationSource(trial:inout RuntimeTrial,control:RuntimeStepControl) throws(RuntimeFailure) {
        let h=history.mechanics
        guard let expected=source.checkpoint.contributors.first(where:{$0.id == owner.schema.id}),try trial.contributor(owner.schema.id) == expected,trial.timeSeconds == h.acceptedTime else { throw RuntimeFailure(.invalidOwnerAccess,message:"Loaded trial record/time source changed.") }
        for i in h.position.indices { try control.beginWorkBlock(units:1);guard try trial.position(at:i) == h.position[i],try trial.velocity(at:i) == h.velocity[i] else { throw RuntimeFailure(.invalidOwnerAccess,message:"Loaded trial q/v source changed.") } }
    }
    @inline(never)
    private func prepareRestProof(work:inout NumericalWork) throws(RuntimeFailure) {
        let proof=try owner.restProof(physical:source.checkpoint.physical,history:history,equation:base,execution:execution,work:&work)
        prepared.store(proof)
        guard !omitted || proof != nil else { throw RuntimeFailure(.invalidContributor,message:"Loaded sleeping source has no actual equilibrium proof.") }
    }
    func derivative(time:Double,point:[Double],into output:inout [Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try owner.check();try control.beginWorkBlock(units:1)
        if !omitted { try base.derivative(time:time,point:point,into:&output,work:&work,control:control);return }
        let h=history.mechanics
        guard point == h.position+h.velocity,output.count == point.count,time.isFinite,time >= h.acceptedTime,time <= owner.constraints.maximumTime,
              prepared.read(position:h.position,drive:h.drive,selection:history.selection) != nil else { throw RuntimeFailure(.invalidState,message:"Loaded omitted stage changed its stationary physical/source authority.") }
        try owner.numerical { () throws(NumericalError) in try work.chargeOperations(try NumericalWork.product(4,h.position.count)) }
        for i in output.indices { try control.beginWorkBlock(units:1);output[i]=0 }
    }
    func write(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial) throws(RuntimeFailure) {
        try owner.check();let h=history.mechanics,n=h.position.count
        guard h.acceptedSequence < UInt64.max else { throw RuntimeFailure(.integerOverflow,message:"Loaded accepted sequence overflow.") }
        try base.write(point:point,derivative:derivative,time:time,trial:&trial)
        var flags=[Bool](repeating:false,count:n),since=[Double](repeating:time,count:n)
        if point[..<n].elementsEqual(h.position),point[n...].allSatisfy({$0 == 0}),derivative.allSatisfy({$0 == 0}),let proof=prepared.read(position:h.position,drive:h.drive,selection:history.selection) {
            for group in proof.groups {
                guard let first=group.first,group.allSatisfy({h.restSince[$0] == h.restSince[first]}) else { throw RuntimeFailure(.invalidContributor,message:"Loaded connected rest onset differs.") }
                for i in group { since[i]=h.restSince[first];flags[i]=time-since[i] >= owner.policy.minimumRestDuration }
            }
        }
        let updated=MechanismSleepHistory(time:time,sequence:h.acceptedSequence+1,q:Array(point[..<n]),v:Array(point[n...]),drive:h.drive,generation:h.commandGeneration,asleep:flags,restSince:since,wakeSequence:h.wakeSequence,kind:h.lastWakeKind,coordinates:h.lastWakeCoordinates)
        try trial.replaceContributor(owner.record(LoadedMechanismSleepHistory(mechanics:updated,selection:history.selection,previousProgramID:history.previousProgramID,previousRevision:history.previousRevision)))
    }
}

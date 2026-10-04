@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class SleepMechanismEquation:SmoothODEEquations, Sendable {
    let owner:CheckpointedMechanismSleep
    let source:RuntimeAcceptedState
    let history:MechanismSleepHistory
    let base:AffineMechanismEquation
    private let prepared=SleepPreparedProof()
    var descriptor:ODEDescriptor { owner.descriptor }
    private var omitted:Bool { history.asleep.allSatisfy({$0}) }
    init(owner:CheckpointedMechanismSleep,source:RuntimeAcceptedState,history:MechanismSleepHistory) throws(RuntimeFailure) {
        self.owner=owner;self.source=source;self.history=history;base=try owner.equation(drive:history.drive)
    }
    func validate(model:CompiledMechanicalModel) throws(RuntimeFailure) { try base.validate(model:model) }
    func read(_ state:KinematicState,into point:inout [Double]) throws(RuntimeFailure) { try base.read(state,into:&point) }
    func read(_ trial:RuntimeTrial,into point:inout [Double]) throws(RuntimeFailure) { try base.read(trial,into:&point) }
    @inline(never)
    func prepare(trial:inout RuntimeTrial,work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try validateSource(trial,control:control)
        try prepareProof(work:&work)
        if !omitted { try base.prepare(trial:&trial,work:&work,control:control) }
    }
    @inline(never)
    private func validateSource(_ trial:RuntimeTrial,control:RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1);try owner.sleepCheck()
        let record=try trial.contributor(owner.schema.id)
        guard let expected=source.checkpoint.contributors.first(where:{$0.id == owner.schema.id}),record == expected,
              trial.timeSeconds == source.checkpoint.physical.time else { throw RuntimeFailure(.invalidOwnerAccess,message:"Sleep trial source record/time changed.") }
        for i in history.position.indices {
            try control.beginWorkBlock(units:1)
            guard try trial.position(at:i) == history.position[i],try trial.velocity(at:i) == history.velocity[i] else {
                throw RuntimeFailure(.invalidOwnerAccess,message:"Sleep trial physical source changed.")
            }
        }
    }
    @inline(never)
    private func prepareProof(work:inout NumericalWork) throws(RuntimeFailure) {
        let proof=try owner.restCertificate(physical:source.checkpoint.physical,drive:history.drive,work:&work)
        prepared.store(proof)
        guard !omitted || proof != nil else { throw RuntimeFailure(.invalidContributor,message:"Sleeping source has no genuine static rest certificate.") }
    }
    func derivative(time:Double,point:[Double],into output:inout [Double],work:inout NumericalWork,control:RuntimeStepControl) throws(RuntimeFailure) {
        try control.beginWorkBlock(units:1);try owner.sleepCheck()
        if !omitted { try base.derivative(time:time,point:point,into:&output,work:&work,control:control);return }
        let n=history.position.count
        guard point.count == 2*n,output.count == point.count,point == history.position+history.velocity,
              time.isFinite,time >= history.acceptedTime,time >= owner.constraints.minimumTime,time <= owner.constraints.maximumTime,
              prepared.read() != nil else {
            throw RuntimeFailure(.invalidState,message:"Omitted stage changed stationary source or validity interval.")
        }
        try owner.sleepNumerical { () throws(NumericalError) in try work.chargeOperations(try NumericalWork.product(4,n)) }
        // Static provenance + exact original equilibrium proves this actual vector field at unchanged q/v.
        for i in output.indices { try control.beginWorkBlock(units:1);output[i]=0 }
    }
    func write(point:[Double],derivative:[Double],time:Double,trial:inout RuntimeTrial) throws(RuntimeFailure) {
        try owner.sleepCheck()
        guard history.acceptedSequence < UInt64.max else { throw RuntimeFailure(.integerOverflow,message:"Sleep accepted sequence overflow.") }
        try base.write(point:point,derivative:derivative,time:time,trial:&trial)
        let n=history.position.count
        var flags=[Bool](repeating:false,count:n),since=[Double](repeating:time,count:n)
        let isRest=point.count == 2*n && point[..<n].elementsEqual(history.position) && point[n...].allSatisfy({$0 == 0}) && derivative.allSatisfy({$0 == 0})
        if isRest,let proof=prepared.read() {
            for group in proof.groups {
                guard let first=group.first else { throw RuntimeFailure(.invalidState,message:"Empty connected sleep group.") }
                let onset=history.restSince[first]
                guard group.allSatisfy({history.restSince[$0] == onset}) else { throw RuntimeFailure(.invalidContributor,message:"Connected rest onset differs.") }
                for index in group { since[index]=onset;flags[index]=time-onset >= owner.policy.minimumRestDuration }
            }
        }
        let updated=MechanismSleepHistory(time:time,sequence:history.acceptedSequence+1,q:Array(point[..<n]),v:Array(point[n...]),drive:history.drive,
            generation:history.commandGeneration,asleep:flags,restSince:since,wakeSequence:history.wakeSequence,kind:history.lastWakeKind,coordinates:history.lastWakeCoordinates)
        try trial.replaceContributor(owner.record(updated))
    }
}

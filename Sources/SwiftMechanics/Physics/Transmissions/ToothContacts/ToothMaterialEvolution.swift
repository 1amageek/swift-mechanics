extension ReferenceToothContactEvolution {
    @inline(never)
    public func initialMaterial(time: Double, q: [Double], v: [Double], policy: ToothContactPolicy,
                                work: inout ToothContactWork) throws(ToothContactError) -> MaterialToothContactState {
        try model.validatePolicy(policy,work:&work)
        guard let material else { throw .unsupportedDomain }
        guard time.isFinite, time >= 0, q.count == 2, v.count == 2 else { throw .invalidInput }
        try work.charge(64)
        let provisional: KinematicState
        do { provisional=try KinematicState(revision:model.tree.revision,time:time,q:q,v:v,acceleration:[0,0]) }
        catch { throw .joint(error) }
        let histories=try physics.history(time:time,policy:policy,work:&work)
        let sample=try material.evaluate(state:provisional,histories:histories,start:time,step:nil,policy:policy,work:&work)
        return try materialPublish(source:nil,provisional:provisional,sample:sample,step:0,policy:policy,work:&work)
    }
    @inline(never)
    public func stepMaterial(accepted: MaterialToothContactState, timeStep: Double, policy: ToothContactPolicy,
                             work: inout ToothContactWork) throws(ToothContactError) -> MaterialToothContactState {
        try model.validatePolicy(policy,work:&work); try accepted.model.validatePolicy(policy,work:&work)
        guard let material else { throw .unsupportedDomain }
        guard model.matches(accepted.model), accepted.physical.revision == model.tree.revision,
              accepted.histories.count == model.contacts.count else { throw .staleSource }
        guard policy.maximumSteps >= 1, accepted.acceptedSteps < UInt64.max else { throw .capacityExceeded }
        let source=accepted.physical, end=source.time+timeStep
        guard timeStep.isFinite, timeStep > 0, end.isFinite, end > source.time else { throw .invalidInput }
        try work.charge(512)
        let start=try material.evaluate(state:source,histories:accepted.histories,start:source.time,step:nil,policy:policy,work:&work)
        guard start.histories == accepted.histories, start.rigid.acceleration == source.acceleration,
              start.normal == accepted.normalStoredEnergy, start.tangent == accepted.tangentialStoredEnergy,
              start.cohesion == accepted.cohesivePotentialEnergy else { throw .staleSource }
        let provisional=try ToothRetraction.apply(model:model,source:source,acceleration:start.rigid.acceleration,
            timeStep:timeStep,policy:policy,work:&work)
        let endpoint=try material.evaluate(state:provisional,histories:accepted.histories,start:source.time,step:timeStep,policy:policy,work:&work)
        return try materialPublish(source:accepted,provisional:provisional,sample:endpoint,step:timeStep,policy:policy,work:&work)
    }
    @inline(never)
    private func materialPublish(source: MaterialToothContactState?, provisional: KinematicState, sample: ToothMaterialSample,
                                 step: Double, policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> MaterialToothContactState {
        try work.charge(256)
        let drive: Double, normalLoss: Double, resistanceLoss: Double, tangentLoss: Double, initial: Double, steps: UInt64
        if let source {
            drive=try ToothArithmetic.value(source.accumulatedDriveWork+model.driveForce[0]*(provisional.q[0]-source.physical.q[0]) +
                model.driveForce[1]*(provisional.q[1]-source.physical.q[1]))
            normalLoss=try ToothArithmetic.value(source.accumulatedNormalDissipation+0.5*step*(source.normalDissipationPower+sample.normalPower))
            resistanceLoss=try ToothArithmetic.value(source.accumulatedResistanceDissipation+0.5*step*(source.resistanceDissipationPower+sample.resistancePower))
            tangentLoss=try ToothArithmetic.value(source.accumulatedTangentialDissipation+sample.tangentLoss)
            initial=source.initialTotalEnergy; steps=source.acceptedSteps+1
            for i in sample.histories.indices {
                let old=source.histories[i], next=sample.histories[i]
                guard old.sequence < UInt64.max, next.sequence == old.sequence+1, next.timeSeconds == provisional.time,
                      next.identity == old.identity, next.pair == old.pair else { throw .invalidSupplierOutput }
                try ToothArithmetic.close(next.cumulativeTangentialDissipation-old.cumulativeTangentialDissipation,
                    sample.observations[i].tangentialDissipationEnergy,scale:policy.dynamics.energyScale,policy:policy)
            }
        } else {
            drive=0; normalLoss=0; resistanceLoss=0; tangentLoss=0; initial=try ToothArithmetic.value(sample.rigid.energy.kineticEnergy+sample.stored); steps=0
        }
        let defect=try ToothArithmetic.value(sample.rigid.energy.kineticEnergy+sample.stored-initial-drive+normalLoss+resistanceLoss+tangentLoss)
        guard abs(defect) <= policy.maximumEnergyDefect else { throw .energyDefect(value:defect,maximum:policy.maximumEnergyDefect) }
        let physical: KinematicState
        do { physical=try KinematicState(revision:model.tree.revision,time:provisional.time,q:provisional.q,v:provisional.v,acceleration:sample.rigid.acceleration) }
        catch { throw .joint(error) }
        try ToothArithmetic.check(policy)
        return MaterialToothContactState(model:model,physical:physical,sample:sample,initialEnergy:initial,drive:drive,
            normalLoss:normalLoss,resistanceLoss:resistanceLoss,tangentLoss:tangentLoss,defect:defect,steps:steps)
    }
    @inline(never)
    public func advanceMaterial(accepted: MaterialToothContactState, to time: Double, timeStep: Double, policy: ToothContactPolicy,
                                work: inout ToothContactWork) throws(MaterialToothContactFailure) -> MaterialToothContactAdvance {
        var current=accepted, completed=0
        do throws(ToothContactError) {
            try model.validatePolicy(policy,work:&work); try current.model.validatePolicy(policy,work:&work)
            guard material != nil else { throw .unsupportedDomain }
            guard model.matches(current.model) else { throw .staleSource }
            guard time.isFinite, time >= current.physical.time, timeStep.isFinite, timeStep > 0 else { throw .invalidInput }
            while current.physical.time < time {
                guard completed < policy.maximumSteps else { throw .capacityExceeded }
                current=try stepMaterial(accepted:current,timeStep:min(timeStep,time-current.physical.time),policy:policy,work:&work)
                completed += 1
            }
            guard current.physical.time == time else { throw .invalidInput }
            try ToothArithmetic.check(policy)
            return MaterialToothContactAdvance(accepted:current,completedSteps:completed,work:work)
        } catch { throw MaterialToothContactFailure(cause:error,accepted:current,work:work,completedSteps:completed) }
    }
}

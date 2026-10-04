public struct ReferenceToothContactEvolution: ToothContactEvolving, Sendable {
    public let model: ToothContactModel
    private let physics: ToothContactPhysics
    public init(model: ToothContactModel, geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries(),
                laws: any ContactLawEvaluating = CompliantContactEvaluator(), dynamics: any RigidDynamicsSolving = DenseRigidDynamics()) {
        self.model=model; physics=ToothContactPhysics(model:model,geometry:geometry,laws:laws,dynamics:dynamics)
    }
    @inline(never)
    public func initial(time: Double, q: [Double], v: [Double], evaluationTimeStep: Double, policy: ToothContactPolicy,
                        work: inout ToothContactWork) throws(ToothContactError) -> ToothContactState {
        try model.validatePolicy(policy,work:&work)
        guard time.isFinite, time >= 0, evaluationTimeStep.isFinite, evaluationTimeStep > 0, q.count == 2, v.count == 2,
              time+evaluationTimeStep > time, (time+evaluationTimeStep).isFinite else { throw .invalidInput }
        try work.charge(64)
        let provisional: KinematicState
        do { provisional=try KinematicState(revision:model.tree.revision,time:time,q:q,v:v,acceleration:[0,0]) }
        catch { throw .joint(error) }
        let histories=try physics.history(time:time,policy:policy,work:&work)
        let sample=try physics.evaluate(state:provisional,histories:histories,intervalStart:time,timeStep:evaluationTimeStep,policy:policy,work:&work)
        let physical: KinematicState
        do { physical=try KinematicState(revision:model.tree.revision,time:time,q:q,v:v,acceleration:sample.acceleration) }
        catch { throw .joint(error) }
        try ToothArithmetic.check(policy)
        return ToothContactState(model:model,physical:physical,histories:histories,sample:sample,
            initialTotalEnergy:try ToothArithmetic.value(sample.energy.kineticEnergy+sample.storedEnergy),driveWork:0,dissipation:0,defect:0,steps:0)
    }
    @inline(never)
    public func step(accepted: ToothContactState, timeStep: Double, policy: ToothContactPolicy,
                     work: inout ToothContactWork) throws(ToothContactError) -> ToothContactState {
        try model.validatePolicy(policy,work:&work); try accepted.model.validatePolicy(policy,work:&work)
        guard model.matches(accepted.model), accepted.physical.revision == model.tree.revision,
              accepted.histories.count == model.contacts.count else { throw .staleSource }
        guard policy.maximumSteps >= 1, accepted.acceptedSteps < UInt64.max else { throw .capacityExceeded }
        let source=accepted.physical, end=source.time+timeStep
        guard timeStep.isFinite, timeStep > 0, end.isFinite, end > source.time else { throw .invalidInput }
        try work.charge(512)
        let start=try physics.evaluate(state:source,histories:accepted.histories,intervalStart:source.time,timeStep:timeStep,policy:policy,work:&work)
        for i in 0..<2 {
            guard source.acceleration[i] == start.acceleration[i] else { throw .staleSource }
        }
        let provisional=try retract(source,start:start,timeStep:timeStep,policy:policy,work:&work)
        let endpoint=try physics.evaluate(state:provisional,histories:accepted.histories,intervalStart:source.time,timeStep:timeStep,policy:policy,work:&work)
        return try publish(source:accepted,endpoint:endpoint,provisional:provisional,timeStep:timeStep,policy:policy,work:&work)
    }
    @inline(never)
    private func retract(_ source: KinematicState, start: ToothPhysicalSample, timeStep: Double,
                         policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> KinematicState {
        try ToothArithmetic.check(policy); try work.charge(1024)
        let velocity=try [ToothArithmetic.value(source.v[0]+timeStep*start.acceleration[0]),
                          ToothArithmetic.value(source.v[1]+timeStep*start.acceleration[1])]
        var positions=source.q
        let evaluator: any JointMotionEvaluating=JointMotionEvaluator()
        for (index,joint) in model.tree.joints.enumerated() {
            let layout=model.tree.layout.joints[index]
            let integrated: [Double]
            do { integrated=try evaluator.integrating(joint.manifold,q:source.q[layout.positions.start..<layout.positions.end],
                v:velocity[layout.velocities.start..<layout.velocities.end],timeStep:timeStep,policy:model.jointPolicy) }
            catch let e as JointError { throw .joint(e) }
            catch let e as CoreError { throw .core(e) }
            catch { throw .unexpectedKinematicsFailure }
            guard integrated.count == layout.positions.count else { throw .invalidSupplierOutput }
            positions[layout.positions.start]=integrated[0]
        }
        do { return try KinematicState(revision:model.tree.revision,time:source.time+timeStep,q:positions,v:velocity,acceleration:start.acceleration) }
        catch { throw .joint(error) }
    }
    @inline(never)
    private func publish(source: ToothContactState, endpoint: ToothPhysicalSample, provisional: KinematicState, timeStep: Double,
                         policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> ToothContactState {
        try work.charge(256)
        let drive=try ToothArithmetic.value(source.accumulatedDriveWork+model.driveForce[0]*(provisional.q[0]-source.physical.q[0]) +
            model.driveForce[1]*(provisional.q[1]-source.physical.q[1]))
        guard let originalDissipation=source.energy.dissipatedPower else { throw .invalidSupplierOutput }
        let loss=try ToothArithmetic.value(source.accumulatedDissipation+0.5*timeStep*(originalDissipation+endpoint.dissipationPower))
        let defect=try ToothArithmetic.value(endpoint.energy.kineticEnergy+endpoint.storedEnergy-source.initialTotalEnergy-drive+loss)
        guard abs(defect) <= policy.maximumEnergyDefect else { throw .energyDefect(value:defect,maximum:policy.maximumEnergyDefect) }
        for i in endpoint.histories.indices {
            let old=source.histories[i], next=endpoint.histories[i]
            guard old.sequence < UInt64.max, next.sequence == old.sequence+1, next.timeSeconds == provisional.time,
                  next.identity == old.identity, next.pair == old.pair else { throw .invalidSupplierOutput }
        }
        let physical: KinematicState
        do { physical=try KinematicState(revision:model.tree.revision,time:provisional.time,q:provisional.q,v:provisional.v,acceleration:endpoint.acceleration) }
        catch { throw .joint(error) }
        try ToothArithmetic.check(policy)
        return ToothContactState(model:model,physical:physical,histories:endpoint.histories,sample:endpoint,
            initialTotalEnergy:source.initialTotalEnergy,driveWork:drive,dissipation:loss,defect:defect,steps:source.acceptedSteps+1)
    }
    @inline(never)
    public func advance(accepted: ToothContactState, to time: Double, timeStep: Double, policy: ToothContactPolicy,
                        work: inout ToothContactWork) throws(ToothContactFailure) -> ToothContactAdvance {
        var current=accepted, completed=0
        do throws(ToothContactError) {
            guard time.isFinite, time >= current.physical.time, timeStep.isFinite, timeStep > 0 else { throw .invalidInput }
            try model.validatePolicy(policy,work:&work); try current.model.validatePolicy(policy,work:&work)
            guard model.matches(current.model) else { throw .staleSource }
            while current.physical.time < time {
                guard completed < policy.maximumSteps else { throw .capacityExceeded }
                current=try step(accepted:current,timeStep:min(timeStep,time-current.physical.time),policy:policy,work:&work)
                completed += 1
            }
            guard current.physical.time == time else { throw .invalidInput }
            return ToothContactAdvance(accepted:current,completedSteps:completed,work:work)
        } catch { throw ToothContactFailure(cause:error,accepted:current,work:work,completedSteps:completed) }
    }
}

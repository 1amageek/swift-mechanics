import MechanicsFlexible
import MechanicsModel
import MechanicsCollision
import MechanicsCore
import MechanicsNumerics
import MechanicsContactLaws
public struct ValueSurfaceContactTransactions: SurfaceContactTransacting {
    private let mapper: any SurfaceContactForceMapping
    public init(mapper: any SurfaceContactForceMapping = MaterialSurfaceForceMapper()) { self.mapper=mapper }
    @inline(never)
    public func initialState(_ snapshot: DeformingSurfaceSnapshot, bindings: [SurfaceContactBinding], policy p: DeformingContactPolicy,
                             work: inout NumericalWork, lawWork: inout ContactWork) throws(DeformingContactError) -> SurfaceContactState {
        let ordered=try admit(snapshot,bindings:bindings,policy:p,work:&work)
        var histories: [ContactHistory]=[]; histories.reserveCapacity(ordered.count)
        for binding in ordered {
            try SurfaceArithmetic.check(p)
            let history=try mapper.initialHistory(binding.witness,key:binding.key,pair:binding.pair,policy:p,work:&work,lawWork:&lawWork)
            guard history.identity.key == binding.key, history.identity.firstBody == snapshot.surface.body, history.pair == binding.pair,
                  history.timeSeconds == snapshot.timeSeconds, history.sequence == 0 else { throw .invalidSupplierOutput }
            histories.append(history)
        }
        try SurfaceArithmetic.check(p)
        return SurfaceContactState(sample:snapshot,time:snapshot.timeSeconds,histories:histories,generation:0)
    }
    @inline(never)
    public func trial(_ state: SurfaceContactState, snapshot: DeformingSurfaceSnapshot, bindings: [SurfaceContactBinding], timeStep: Double,
                      policy p: DeformingContactPolicy, lawPolicy: ContactAcceptancePolicy, work: inout NumericalWork,
                      lawWork: inout ContactWork) throws(DeformingContactError) -> SurfaceContactStep {
        try SurfaceArithmetic.check(p)
        guard state.histories.count <= p.maximumContacts else { throw .capacityExceeded }
        let ordered=try admit(snapshot,bindings:bindings,policy:p,work:&work)
        guard state.sample.surface === snapshot.surface, snapshot.timeSeconds == state.acceptedTime,
              snapshot.geometryRevision >= state.sample.geometryRevision, state.generation < UInt64.max,
              ordered.count == state.histories.count, timeStep.isFinite, timeStep > 0,
              (snapshot.timeSeconds+timeStep).isFinite, snapshot.timeSeconds+timeStep > snapshot.timeSeconds else { throw .staleHistory }
        if snapshot.state.positions != state.sample.state.positions || snapshot.state.velocities != state.sample.state.velocities {
            guard snapshot.geometryRevision > state.sample.geometryRevision else { throw .staleGeometry }
        }
        var forces=[Vector3](repeating:.zero,count:snapshot.state.positions.count), trials: [SurfaceForceTrial]=[]; trials.reserveCapacity(ordered.count)
        for i in ordered.indices {
            try SurfaceArithmetic.check(p)
            let binding=ordered[i], history=state.histories[i]
            guard history.identity.key == binding.key else { throw .staleHistory }
            let result=try mapper.evaluate(binding.witness,current:snapshot,currentObstacle:binding.currentObstacle,key:binding.key,pair:binding.pair,
                accepted:history,timeStep:timeStep,policy:p,lawPolicy:lawPolicy,work:&work,lawWork:&lawWork)
            guard result.witness === binding.witness, result.response.trialHistory.identity == history.identity,
                  result.response.trialHistory.pair == history.pair, result.response.trialHistory.timeSeconds == snapshot.timeSeconds+timeStep,
                  history.sequence < UInt64.max, result.response.trialHistory.sequence == history.sequence+1,
                  result.nodalForces.count == forces.count else { throw .invalidSupplierOutput }
            for j in forces.indices { try SurfaceArithmetic.charge(32,p,&work); forces[j]=try SurfaceArithmetic.core { () throws(CoreError) in try forces[j].adding(result.nodalForces[j]) } }
            trials.append(result)
        }
        try SurfaceArithmetic.check(p)
        return SurfaceContactStep(source:state,snapshot:snapshot,endpointTime:snapshot.timeSeconds+timeStep,forces:forces,contacts:trials)
    }
    public func accept(_ step: SurfaceContactStep, from state: SurfaceContactState) throws(DeformingContactError) -> SurfaceContactState {
        guard step.source === state else { throw .staleHistory }
        return SurfaceContactState(sample:step.snapshot,time:step.endpointTime,histories:step.contacts.map { $0.response.trialHistory },generation:state.generation+1)
    }
    public func reject(_ step: SurfaceContactStep, from state: SurfaceContactState) throws(DeformingContactError) -> SurfaceContactState {
        guard step.source === state else { throw .staleHistory }; return state
    }
    @inline(never)
    private func admit(_ snapshot: DeformingSurfaceSnapshot, bindings: [SurfaceContactBinding], policy p: DeformingContactPolicy,
                       work: inout NumericalWork) throws(DeformingContactError) -> [SurfaceContactBinding] {
        try SurfaceQueryAdmission.snapshot(snapshot,policy:p,work:&work)
        guard !bindings.isEmpty, bindings.count <= p.maximumContacts else { throw .capacityExceeded }
        let count=try SurfaceArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(NumericalWork.product(NumericalWork.product(3,snapshot.state.positions.count),NumericalWork.sum(bindings.count,2)),NumericalWork.product(512,bindings.count)) }
        try SurfaceArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(count) }
        for i in bindings.indices {
            try SurfaceArithmetic.text(bindings[i].key,p,&work)
            if let obstacle=bindings[i].currentObstacle { try SurfaceQueryAdmission.geometry(obstacle.geometry,policy:p,work:&work) }
            if let obstacle=bindings[i].witness.obstacle { try SurfaceQueryAdmission.geometry(obstacle.geometry,policy:p,work:&work) }
            guard bindings[i].currentObstacle == bindings[i].witness.obstacle, bindings[i].witness.snapshot.surface === snapshot.surface,
                  bindings[i].witness.snapshot.geometryRevision == snapshot.geometryRevision, bindings[i].witness.snapshot.timeSeconds == snapshot.timeSeconds,
                  bindings[i].witness.snapshot.state.positions == snapshot.state.positions, bindings[i].witness.snapshot.state.velocities == snapshot.state.velocities else { throw .staleGeometry }
            for j in 0..<i { try SurfaceArithmetic.charge(1,p,&work); guard bindings[i].key != bindings[j].key else { throw .invalidInput } }
        }
        return bindings.sorted { $0.key < $1.key }
    }
}

import SwiftMechanics
import Synchronization

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandEquationFault: RigidEquationComputing {
    enum Mode:Sendable { case numericalReset,loadReset,cancelReset,wrongSource }
    let mode:Mode
    private let calls=Mutex(0)
    var count:Int { calls.withLock {$0} }
    init(_ mode:Mode) { self.mode=mode }
    func assemble(_ input:RigidDynamicsInput,admission:DynamicsAdmission,loadWork:inout LoadWork,work:inout NumericalWork) throws(DynamicsError) -> RigidDynamicsSystem {
        calls.withLock {$0 += 1}
        let actual=try RigidEquationKernel().assemble(input,admission:admission,loadWork:&loadWork,work:&work)
        switch mode {
        case .numericalReset:work=NumericalWork(budget:work.budget)
        case .loadReset:loadWork=LoadWork(budget:loadWork.budget)
        case .cancelReset:work=NumericalWork(budget:work.budget);loadWork=LoadWork(budget:loadWork.budget);throw .cancelled
        case .wrongSource:
            do {
                let n=input.velocity.count
                let state=try KinematicState(revision:input.snapshot.tree.revision,time:input.snapshot.time,q:[Double](repeating:0.2,count:n),v:input.velocity,acceleration:[Double](repeating:0,count:n))
                let tolerance=try NumericalTolerance(absolute:1e-12,relative:1e-12)
                let snapshot=try TreeKinematicsEvaluator().evaluate(input.snapshot.tree,state:state,policy:JointEvaluationPolicy(quaternionTolerance:tolerance,chartRankRelative:1e-10,characteristicLengthMeters:1))
                return try RigidEquationKernel().assemble(RigidDynamicsInput(snapshot:snapshot,velocity:input.velocity,inertias:input.inertias,gravity:nil),admission:admission,loadWork:&loadWork,work:&work)
            } catch { throw .invalidInput }
        }
        return actual
    }
    func originalInertialForce(_ system:RigidDynamicsSystem,acceleration:[Double],includeBias:Bool,into output:inout [Double],work:inout NumericalWork) throws(DynamicsError) {
        try RigidEquationKernel().originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
    }
    func inertialWrench(_ system:RigidDynamicsSystem,body:EntityID,acceleration:[Double],referencePointWorld:Vector3,work:inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        try RigidEquationKernel().inertialWrench(system,body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
    }
    func energy(_ system:RigidDynamicsSystem,acceleration:[Double],angularMomentumReference:Vector3,requireComplete:Bool,work:inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        try RigidEquationKernel().energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
    }
}

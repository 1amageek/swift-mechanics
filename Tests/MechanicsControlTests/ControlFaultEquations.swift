import SwiftMechanics

struct ControlFaultEquations: RigidEquationComputing {
    enum Fault:Sendable { case poisonedForce,resetThenThrow }
    let fault:Fault
    func assemble(_ input:RigidDynamicsInput,admission:DynamicsAdmission,loadWork:inout LoadWork,work:inout NumericalWork) throws(DynamicsError) -> RigidDynamicsSystem {
        let system=try RigidEquationKernel().assemble(input,admission:admission,loadWork:&loadWork,work:&work)
        if fault == .resetThenThrow { work=NumericalWork(budget:work.budget);loadWork=LoadWork(budget:loadWork.budget);throw .nonFiniteResult }
        return system
    }
    func originalInertialForce(_ system:RigidDynamicsSystem,acceleration:[Double],includeBias:Bool,into output:inout [Double],work:inout NumericalWork) throws(DynamicsError) {
        try RigidEquationKernel().originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
        if fault == .poisonedForce { output[0] = .nan }
    }
    func inertialWrench(_ system:RigidDynamicsSystem,body:EntityID,acceleration:[Double],referencePointWorld:Vector3,work:inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        try RigidEquationKernel().inertialWrench(system,body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
    }
    func energy(_ system:RigidDynamicsSystem,acceleration:[Double],angularMomentumReference:Vector3,requireComplete:Bool,work:inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        try RigidEquationKernel().energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
    }
}

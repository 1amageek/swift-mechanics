import SwiftMechanics

internal struct PhysicalMechanismFaultKernel: PhysicalRigidEquationComputing {
    enum Fault: Sendable { case resetReturn, resetThrow, fail }
    let fault:Fault
    func assemble(_ input:PhysicalRigidDynamicsInput,admission:DynamicsAdmission,loadWork:inout LoadWork,work:inout NumericalWork) throws(DynamicsError) -> PhysicalRigidDynamicsSystem {
        try RigidEquationKernel().assemble(input,admission:admission,loadWork:&loadWork,work:&work)
    }
    func originalInertialForce(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],includeBias:Bool,into output:inout [Double],work:inout NumericalWork) throws(DynamicsError) {
        try RigidEquationKernel().originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
        switch fault {
        case .resetReturn: work=NumericalWork(budget:work.budget)
        case .resetThrow: work=NumericalWork(budget:work.budget);throw .energyUnavailable
        case .fail: throw .energyUnavailable
        }
    }
    func inertialWrench(_ system:PhysicalRigidDynamicsSystem,body:EntityID,acceleration:[Double],referencePointWorld:Vector3,work:inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        try RigidEquationKernel().inertialWrench(system,body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
    }
    func energy(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],angularMomentumReference:Vector3,requireComplete:Bool,work:inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        try RigidEquationKernel().energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
    }
}

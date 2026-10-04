import SwiftMechanics

internal struct MovingEnergyFaultKernel: RigidEquationComputing {
    enum Fault:Sendable { case source,resetSuccess,resetFailure }
    let fault:Fault
    private let original=RigidEquationKernel()
    func assemble(_ input:RigidDynamicsInput,admission:DynamicsAdmission,loadWork:inout LoadWork,work:inout NumericalWork) throws(DynamicsError) -> RigidDynamicsSystem {
        try original.assemble(input,admission:admission,loadWork:&loadWork,work:&work)
    }
    func originalInertialForce(_ system:RigidDynamicsSystem,acceleration:[Double],includeBias:Bool,into output:inout [Double],work:inout NumericalWork) throws(DynamicsError) {
        try original.originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
    }
    func inertialWrench(_ system:RigidDynamicsSystem,body:EntityID,acceleration:[Double],referencePointWorld:Vector3,work:inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        try original.inertialWrench(system,body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
    }
    func energy(_ system:RigidDynamicsSystem,acceleration:[Double],angularMomentumReference:Vector3,requireComplete:Bool,work:inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        if system.input.snapshot.time > 0.051 {
            switch fault {
            case .source:
                var other=acceleration;other[0]+=0.3
                return try original.energy(system,acceleration:other,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
            case .resetSuccess:
                let result=try original.energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
                work=NumericalWork(budget:work.budget);return result
            case .resetFailure: work=NumericalWork(budget:work.budget);throw .invalidInput
            }
        }
        return try original.energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
    }
}

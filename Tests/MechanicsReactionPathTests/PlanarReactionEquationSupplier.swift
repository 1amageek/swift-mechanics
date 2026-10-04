import SwiftMechanics

internal struct PlanarReactionEquationSupplier: PhysicalRigidEquationComputing {
    let foreign: PhysicalRigidDynamicsSystem?
    let reset: Bool
    let fails: Bool
    init(foreign:PhysicalRigidDynamicsSystem?=nil,reset:Bool=false,fails:Bool=false) { self.foreign=foreign;self.reset=reset;self.fails=fails }
    func assemble(_ input:PhysicalRigidDynamicsInput,admission:DynamicsAdmission,loadWork:inout LoadWork,work:inout NumericalWork) throws(DynamicsError)->PhysicalRigidDynamicsSystem {
        try RigidEquationKernel().assemble(input,admission:admission,loadWork:&loadWork,work:&work)
    }
    func originalInertialForce(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],includeBias:Bool,into output:inout [Double],work:inout NumericalWork) throws(DynamicsError) {
        try RigidEquationKernel().originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
    }
    func inertialWrench(_ system:PhysicalRigidDynamicsSystem,body:EntityID,acceleration:[Double],referencePointWorld:Vector3,work:inout NumericalWork) throws(DynamicsError)->BodyWrenchEvidence {
        let result=try RigidEquationKernel().inertialWrench(foreign ?? system,body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
        if reset { work=NumericalWork(budget:work.budget) }
        if fails { throw .cancelled }
        return result
    }
    func energy(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],angularMomentumReference:Vector3,requireComplete:Bool,work:inout NumericalWork) throws(DynamicsError)->MechanicalEnergy {
        try RigidEquationKernel().energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
    }
}

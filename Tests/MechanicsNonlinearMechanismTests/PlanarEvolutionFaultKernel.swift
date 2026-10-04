import SwiftMechanics

/// Faults delegate real admitted producers before perturbing the source or ledger boundary.
internal struct PlanarEvolutionFaultKernel: PhysicalRigidEquationComputing {
    enum Fault: Sendable { case wrongSource, resetSuccess, resetFailure, cancel }
    let model:CompiledMechanicalModel
    let fault:Fault
    func assemble(_ input:PhysicalRigidDynamicsInput,admission:DynamicsAdmission,loadWork:inout LoadWork,
                  work:inout NumericalWork) throws(DynamicsError) -> PhysicalRigidDynamicsSystem {
        if fault == .wrongSource,input.snapshot.time >= 0.075 {
            guard case .planar(let original)=input.source else { throw .unsupportedDomain }
            do throws(NumericalError) { try work.chargeOperations(try NumericalWork.product(512,try NumericalWork.product(model.tree.bodies.count,1+input.velocity.count))) }
            catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
            var q=model.descriptor.initialState.q;q[0]+=0.01
            let snapshot:KinematicSnapshot
            do { snapshot=try model.evaluate(model.makeState(KinematicState(revision:model.stamp.revision,time:input.snapshot.time,
                q:q,v:input.velocity,acceleration:[Double](repeating:0,count:input.velocity.count)))) }
            catch { throw .invalidInput }
            let changed=try PlanarRigidDynamicsInput(snapshot:snapshot,velocity:original.velocity,inertias:original.inertias,
                gravity:original.gravity,bodyWrenches:original.bodyWrenches,generalizedForces:original.generalizedForces)
            return try RigidEquationKernel().assemble(PhysicalRigidDynamicsInput(planar:changed),admission:admission,loadWork:&loadWork,work:&work)
        }
        return try RigidEquationKernel().assemble(input,admission:admission,loadWork:&loadWork,work:&work)
    }
    func originalInertialForce(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],includeBias:Bool,
                              into output:inout [Double],work:inout NumericalWork) throws(DynamicsError) {
        try RigidEquationKernel().originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
    }
    func inertialWrench(_ system:PhysicalRigidDynamicsSystem,body:EntityID,acceleration:[Double],referencePointWorld:Vector3,
                       work:inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        try RigidEquationKernel().inertialWrench(system,body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
    }
    func energy(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],angularMomentumReference:Vector3,
                requireComplete:Bool,work:inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        let result=try RigidEquationKernel().energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
        if system.input.snapshot.time >= 0.075 {
            switch fault {
            case .wrongSource: break
            case .resetSuccess: work=NumericalWork(budget:work.budget)
            case .resetFailure: work=NumericalWork(budget:work.budget);throw .energyUnavailable
            case .cancel: throw .cancelled
            }
        }
        return result
    }
}

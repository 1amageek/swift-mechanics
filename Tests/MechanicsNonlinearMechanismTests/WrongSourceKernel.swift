import SwiftMechanics

internal struct WrongSourceKernel: RigidEquationComputing, Sendable {
    enum Change: Sendable { case pose, inertia, load }
    let model:CompiledMechanicalModel
    let change:Change
    func assemble(_ input:RigidDynamicsInput,admission:DynamicsAdmission,loadWork:inout LoadWork,work:inout NumericalWork) throws(DynamicsError) -> RigidDynamicsSystem {
        let alternate:RigidDynamicsInput
        do {
            let snapshot:KinematicSnapshot
            if case .pose=change {
                snapshot=try model.evaluate(model.makeState(KinematicState(revision:model.stamp.revision,time:input.snapshot.time,q:[0,1],v:input.velocity,acceleration:[0,0])))
            } else { snapshot=input.snapshot }
            var inertias=input.inertias,loads=input.generalizedForces
            if case .inertia=change {
                let tolerance=try NumericalTolerance(absolute:1e-12,relative:1e-12)
                let properties=try MassProperties3D(mass:2,centerOfMass:.zero,inertiaAtCenter:Matrix3(2,0,0,0,2,0,0,0,2),policy:InertiaValidationPolicy(symmetry:tolerance,physicalityRelative:0))
                inertias[1]=try RigidBodyInertia(body:inertias[1].body,frame:inertias[1].frame,properties:properties)
            }
            if case .load=change { loads.append(try GeneralizedForceContribution(values:[1,0],channel:.applied)) }
            alternate=try RigidDynamicsInput(snapshot:snapshot,velocity:input.velocity,inertias:inertias,gravity:input.gravity,bodyWrenches:input.bodyWrenches,generalizedForces:loads)
        } catch { throw .invalidInput }
        return try RigidEquationKernel().assemble(alternate,admission:admission,loadWork:&loadWork,work:&work)
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

import SwiftMechanics

internal struct WrongSourceMechanismSolver: ConstrainedMechanismSolving, Sendable {
    let model:CompiledMechanicalModel
    private func alternate(_ original:RigidDynamicsSystem,work:inout NumericalWork) throws(MechanismError) -> RigidDynamicsSystem {
        let input:RigidDynamicsInput
        do {
            let q=[0.0,0,0,1],v=original.input.velocity,time=original.input.snapshot.time
            let snapshot=try model.evaluate(model.makeState(KinematicState(revision:model.stamp.revision,time:time,q:q,v:v,acceleration:[0,0,0])))
            input=try RigidDynamicsInput(snapshot:snapshot,velocity:v,inertias:original.input.inertias,gravity:original.input.gravity,
                bodyWrenches:original.input.bodyWrenches,generalizedForces:original.input.generalizedForces)
        } catch { throw .invalidInput }
        let tolerance:NumericalTolerance,capacity:DynamicsCapacity
        do { tolerance=try NumericalTolerance(absolute:1e-10,relative:1e-10);capacity=try DynamicsCapacity(maximumBodies:8,maximumVelocities:8,maximumBodyWrenches:8,maximumGeneralizedContributions:8) }
        catch { throw .invalidInput }
        var load:LoadWork
        do { load=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0)) } catch { throw .invalidInput }
        do throws(DynamicsError) { return try RigidEquationKernel().assemble(input,admission:DynamicsAdmission(capacity:capacity,angularVelocityTolerance:tolerance,linearVelocityTolerance:tolerance),loadWork:&load,work:&work) }
        catch { throw .dynamics(error) }
    }
    func acceleration(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,drive:[Double],policy:MechanismSolvePolicy,
                      work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        let wrong=try alternate(system,work:&work)
        return try MassWeightedMechanismSolver().acceleration(wrong,sample:sample,drive:drive,policy:policy,work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
    }
    func reconcileVelocity(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,policy:MechanismSolvePolicy,
                           work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,linearWork:inout NumericalWork) throws(MechanismError) -> ConstrainedMotion {
        // Preserve the genuine velocity projection so the regression reaches the acceleration supplier publication path.
        try MassWeightedMechanismSolver().reconcileVelocity(system,sample:sample,policy:policy,work:&work,dynamicsWork:&dynamicsWork,rankWork:&rankWork,linearWork:&linearWork)
    }
}

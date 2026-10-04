import SwiftMechanics

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal enum PhysicalMechanismFixtures {
    static func system(_ model:CompiledMechanicalModel) throws -> PhysicalRigidDynamicsSystem {
        var work=try MechanismFixtures.work(),load=LoadWork(budget:try LoadBudget(maximumWork:0,maximumScalars:0))
        let snapshot=try model.evaluate(model.makeState(model.descriptor.initialState))
        let inertias=try model.tree.bodies.map { body -> PlanarRigidBodyInertia in
            guard let raw=model.descriptor.bodies.first(where:{$0.id == body.id}),case .planar(let record)=raw,let inertia=record.inertia else { throw DynamicsError.inertiaIdentityMismatch }
            return try PlanarRigidBodyInertia(body:body.id,frame:body.frame,properties:inertia.properties)
        }
        return try RigidEquationKernel().assemble(PhysicalRigidDynamicsInput(planar:PlanarRigidDynamicsInput(snapshot:snapshot,
            velocity:model.descriptor.initialState.v,inertias:inertias,gravity:nil)),admission:MechanismFixtures.admission(),loadWork:&load,work:&work)
    }
    static func solver() -> MassWeightedMechanismSolver {
        MassWeightedMechanismSolver(physicalDynamics:DenseRigidDynamics(physicalEquations:RigidEquationKernel()),physicalEquations:RigidEquationKernel())
    }
}

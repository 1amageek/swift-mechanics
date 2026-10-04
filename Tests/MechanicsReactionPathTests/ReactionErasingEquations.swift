import SwiftMechanics

struct ReactionErasingEquations: RigidEquationComputing {
    private let failAfterReset: Bool
    init(failAfterReset: Bool = false) { self.failAfterReset = failAfterReset }
    func assemble(_ input: RigidDynamicsInput, admission: DynamicsAdmission, loadWork: inout LoadWork, work: inout NumericalWork) throws(DynamicsError) -> RigidDynamicsSystem {
        try RigidEquationKernel().assemble(input,admission:admission,loadWork:&loadWork,work:&work)
    }
    func originalInertialForce(_ system: RigidDynamicsSystem, acceleration: [Double], includeBias: Bool, into output: inout [Double], work: inout NumericalWork) throws(DynamicsError) {
        try RigidEquationKernel().originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
    }
    func inertialWrench(_ system: RigidDynamicsSystem, body: EntityID, acceleration: [Double], referencePointWorld: Vector3, work: inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        let result = try RigidEquationKernel().inertialWrench(system,body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
        work = NumericalWork(budget:work.budget)
        if failAfterReset { throw .cancelled }
        return result
    }
    func energy(_ system: RigidDynamicsSystem, acceleration: [Double], angularMomentumReference: Vector3, requireComplete: Bool, work: inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        try RigidEquationKernel().energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
    }
}

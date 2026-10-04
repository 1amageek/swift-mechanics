import SwiftMechanics

internal struct PlanarPrescribedRootForeignEquations: PhysicalRigidEquationComputing {
    enum Query: Equatable, Sendable { case force, body }
    let query: Query
    let foreign: PhysicalRigidDynamicsSystem?
    let reset: Bool
    let fails: Bool
    init(query: Query, foreign: PhysicalRigidDynamicsSystem? = nil, reset: Bool = false, fails: Bool = false) {
        self.query=query;self.foreign=foreign;self.reset=reset;self.fails=fails
    }
    func assemble(_ input: PhysicalRigidDynamicsInput, admission: DynamicsAdmission, loadWork: inout LoadWork,
                  work: inout NumericalWork) throws(DynamicsError) -> PhysicalRigidDynamicsSystem {
        try RigidEquationKernel().assemble(input,admission:admission,loadWork:&loadWork,work:&work)
    }
    func originalInertialForce(_ system: PhysicalRigidDynamicsSystem, acceleration: [Double], includeBias: Bool,
                               into output: inout [Double], work: inout NumericalWork) throws(DynamicsError) {
        try RigidEquationKernel().originalInertialForce(query == .force ? foreign ?? system : system,acceleration:acceleration,
            includeBias:includeBias,into:&output,work:&work)
        if query == .force {
            if reset { work=NumericalWork(budget:work.budget) }
            if fails { throw .cancelled }
        }
    }
    func inertialWrench(_ system: PhysicalRigidDynamicsSystem, body: EntityID, acceleration: [Double], referencePointWorld: Vector3,
                       work: inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        let evidence=try RigidEquationKernel().inertialWrench(query == .body ? foreign ?? system : system,
            body:body,acceleration:acceleration,referencePointWorld:referencePointWorld,work:&work)
        if query == .body {
            if reset { work=NumericalWork(budget:work.budget) }
            if fails { throw .cancelled }
        }
        return evidence
    }
    func energy(_ system: PhysicalRigidDynamicsSystem, acceleration: [Double], angularMomentumReference: Vector3,
                requireComplete: Bool, work: inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        try RigidEquationKernel().energy(system,acceleration:acceleration,angularMomentumReference:angularMomentumReference,requireComplete:requireComplete,work:&work)
    }
}

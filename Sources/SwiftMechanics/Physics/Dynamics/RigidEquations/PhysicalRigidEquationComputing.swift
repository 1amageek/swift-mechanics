public protocol PhysicalRigidEquationComputing: Sendable {
    func assemble(_ input: PhysicalRigidDynamicsInput, admission: DynamicsAdmission, loadWork: inout LoadWork,
                  work: inout NumericalWork) throws(DynamicsError) -> PhysicalRigidDynamicsSystem
    func originalInertialForce(_ system: PhysicalRigidDynamicsSystem, acceleration: [Double], includeBias: Bool,
                               into output: inout [Double], work: inout NumericalWork) throws(DynamicsError)
    func inertialWrench(_ system: PhysicalRigidDynamicsSystem, body: EntityID, acceleration: [Double],
                       referencePointWorld: Vector3, work: inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence
    func energy(_ system: PhysicalRigidDynamicsSystem, acceleration: [Double], angularMomentumReference: Vector3,
                requireComplete: Bool, work: inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy
}

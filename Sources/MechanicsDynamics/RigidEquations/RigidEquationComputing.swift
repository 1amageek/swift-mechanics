import MechanicsCore
import MechanicsModel
import MechanicsLoads
import MechanicsNumerics
public protocol RigidEquationComputing: Sendable {
    func assemble(_ input: RigidDynamicsInput, admission: DynamicsAdmission, loadWork: inout LoadWork, work: inout NumericalWork) throws(DynamicsError) -> RigidDynamicsSystem
    func originalInertialForce(_ system: RigidDynamicsSystem, acceleration: [Double], includeBias: Bool,
                               into output: inout [Double], work: inout NumericalWork) throws(DynamicsError)
    func inertialWrench(_ system: RigidDynamicsSystem, body: EntityID, acceleration: [Double],
                        referencePointWorld: Vector3, work: inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence
    func energy(_ system: RigidDynamicsSystem, acceleration: [Double], angularMomentumReference: Vector3,
                requireComplete: Bool, work: inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy
}

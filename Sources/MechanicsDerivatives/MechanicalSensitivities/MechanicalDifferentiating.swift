import MechanicsJoints
import MechanicsDynamics
import MechanicsLoads
import MechanicsNumerics
public protocol MechanicalDifferentiating: Sendable {
    func direction(_ input: MechanicalDerivativeInput, direction: MechanicalDirection, jointPolicy: JointEvaluationPolicy,
                   admission: DynamicsAdmission, policy: DerivativePolicy, workspace: inout MechanicalDerivativeWorkspace,
                   loadWork: inout LoadWork, supplierWork: inout DerivativeSupplierWork, work: inout NumericalWork) throws(DerivativeError) -> MechanicalTangent
    func forwardDirection(_ input: MechanicalDerivativeInput, direction: MechanicalDirection, jointPolicy: JointEvaluationPolicy,
                          admission: DynamicsAdmission, solvePolicy: DynamicsSolvePolicy, policy: DerivativePolicy,
                          workspace: inout MechanicalDerivativeWorkspace, loadWork: inout LoadWork,
                          supplierWork: inout DerivativeSupplierWork, work: inout NumericalWork) throws(DerivativeError) -> AccelerationTangent
    func forwardJacobian(_ input: MechanicalDerivativeInput, variable: MechanicalJacobianVariable, jointPolicy: JointEvaluationPolicy,
                         admission: DynamicsAdmission, solvePolicy: DynamicsSolvePolicy, policy: DerivativePolicy,
                         workspace: inout MechanicalDerivativeWorkspace, loadWork: inout LoadWork,
                         supplierWork: inout DerivativeSupplierWork, work: inout NumericalWork) throws(DerivativeError) -> MechanicalAccelerationJacobian
}

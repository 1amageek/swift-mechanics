public protocol InertialParameterDifferentiating: Sendable {
    func product(_ input: InertialParameterInput, direction: [RigidInertialParameterDirection],
                 jointPolicy: JointEvaluationPolicy, admission: DynamicsAdmission, solvePolicy: DynamicsSolvePolicy,
                 policy: DerivativePolicy,
                 loadWork: inout LoadWork, supplierWork: inout DerivativeSupplierWork,
                 work: inout NumericalWork) throws(InertialParameterError) -> InertialParameterProduct

    func forwardProduct(_ input: InertialParameterInput, direction: [RigidInertialParameterDirection],
                        jointPolicy: JointEvaluationPolicy, admission: DynamicsAdmission, solvePolicy: DynamicsSolvePolicy,
                        policy: DerivativePolicy,
                        loadWork: inout LoadWork, supplierWork: inout DerivativeSupplierWork,
                        work: inout NumericalWork) throws(InertialParameterError) -> InertialParameterAccelerationProduct
}

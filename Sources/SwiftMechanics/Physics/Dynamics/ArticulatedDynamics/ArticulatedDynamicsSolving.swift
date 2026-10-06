public protocol ArticulatedDynamicsSolving: Sendable {
    func forward(_ input: RigidDynamicsInput, driveForce: [Double], policy: ArticulatedDynamicsPolicy,
                 loadWork: inout LoadWork, work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> ArticulatedDynamicsResult
    func inverseMassProduct(_ input: RigidDynamicsInput, rightHandSide: [Double], policy: ArticulatedDynamicsPolicy,
                            loadWork: inout LoadWork, work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> ArticulatedDynamicsResult
}

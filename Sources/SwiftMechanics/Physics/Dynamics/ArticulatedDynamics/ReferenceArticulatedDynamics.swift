public struct ReferenceArticulatedDynamics: ArticulatedDynamicsSolving, Sendable {
    public init() {}
    public func forward(_ input: RigidDynamicsInput, driveForce: [Double], policy: ArticulatedDynamicsPolicy,
                        loadWork: inout LoadWork, work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> ArticulatedDynamicsResult {
        try evaluate(input,rhs:driveForce,operation:.forward,policy:policy,loadWork:&loadWork,work:&work)
    }
    public func inverseMassProduct(_ input: RigidDynamicsInput, rightHandSide: [Double], policy: ArticulatedDynamicsPolicy,
                                   loadWork: inout LoadWork, work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> ArticulatedDynamicsResult {
        try evaluate(input,rhs:rightHandSide,operation:.inverseMass,policy:policy,loadWork:&loadWork,work:&work)
    }
    @inline(never)
    private func evaluate(_ input: RigidDynamicsInput, rhs: [Double], operation: ArticulatedDynamicsOperation,
                          policy: ArticulatedDynamicsPolicy, loadWork: inout LoadWork,
                          work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> ArticulatedDynamicsResult {
        let before = work.operations
        let acceleration = try candidate(input,rhs:rhs,operation:operation,policy:policy,loadWork:&loadWork,work:&work)
        let recursiveOperations = work.operations-before
        // The recursive workspace has ended before the rich original physical oracle is entered.
        return try ArticulatedAcceptance.publish(input,acceleration:acceleration,rhs:rhs,operation:operation,
            recursiveOperations:recursiveOperations,policy:policy,loadWork:&loadWork,work:&work)
    }
    @inline(never)
    private func candidate(_ input: RigidDynamicsInput, rhs: [Double], operation: ArticulatedDynamicsOperation,
                           policy: ArticulatedDynamicsPolicy, loadWork: inout LoadWork,
                           work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> [Double] {
        var workspace = try ArticulatedPreparation.make(input,rhs:rhs,operation:operation,policy:policy,loadWork:&loadWork,work:&work)
        return try ArticulatedRecursion.solve(&workspace,input:input,policy:policy,work:&work)
    }
}

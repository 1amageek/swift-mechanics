/// Explicit original witnesses; capability failure never selects another supplier.
internal enum MechanismPhysicalSuppliers: Sendable {
    case spatial(any RigidDynamicsSolving, any RigidEquationComputing)
    case physical(any PhysicalRigidDynamicsSolving, any PhysicalRigidEquationComputing)
    func admit(_ system: PhysicalRigidDynamicsSystem) throws(MechanismError) {
        if case .spatial = self, system.input.dimension != .spatial { throw .unsupportedChart }
    }
    @inline(never)
    func solve(_ system: PhysicalRigidDynamicsSystem, values: [Double], massOnly: Bool,
               policy: DynamicsSolvePolicy, work: inout NumericalWork) throws(DynamicsError) -> MechanismDynamicsValues {
        switch self {
        case .spatial(let dynamics, _):
            let source = try system.spatialSystem()
            let result = massOnly ? try dynamics.inverseMassProduct(source, rightHandSide: values, policy: policy, work: &work)
                : try dynamics.forward(source, driveForce: values, policy: policy, work: &work)
            return MechanismDynamicsValues(acceleration: result.acceleration)
        case .physical(let dynamics, _):
            let result = massOnly ? try dynamics.inverseMassProduct(system, rightHandSide: values, policy: policy, work: &work)
                : try dynamics.forward(system, driveForce: values, policy: policy, work: &work)
            guard result.system === system else { throw .inertiaIdentityMismatch }
            return MechanismDynamicsValues(acceleration: result.acceleration)
        }
    }
    @inline(never)
    func original(_ system: PhysicalRigidDynamicsSystem, acceleration: [Double], into output: inout [Double],
                  work: inout NumericalWork) throws(DynamicsError) {
        switch self {
        case .spatial(_, let equations):
            try equations.originalInertialForce(system.spatialSystem(), acceleration: acceleration, includeBias: true, into: &output, work: &work)
        case .physical(_, let equations):
            try equations.originalInertialForce(system, acceleration: acceleration, includeBias: true, into: &output, work: &work)
        }
    }
}

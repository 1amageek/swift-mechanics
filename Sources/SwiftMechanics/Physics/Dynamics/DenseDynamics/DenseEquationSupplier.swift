/// Explicit witness selection; a legacy supplier is never replaced by a default physical kernel.
internal enum DenseEquationSupplier: Sendable {
    case spatial(any RigidEquationComputing)
    case physical(any PhysicalRigidEquationComputing)
    var requiresPhysicalGuard:Bool {
        switch self { case .spatial:return false;case .physical:return true }
    }
    func original(_ system:PhysicalRigidDynamicsSystem,acceleration:[Double],includeBias:Bool,
                  into output:inout [Double],work:inout NumericalWork) throws(DynamicsError) {
        switch self {
        case .spatial(let equations):
            try equations.originalInertialForce(system.spatialSystem(),acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
        case .physical(let equations):
            try equations.originalInertialForce(system,acceleration:acceleration,includeBias:includeBias,into:&output,work:&work)
        }
    }
    func admit(_ system:PhysicalRigidDynamicsSystem) throws(DynamicsError) {
        if case .spatial=self,system.input.dimension != .spatial { throw .unsupportedDomain }
    }
}

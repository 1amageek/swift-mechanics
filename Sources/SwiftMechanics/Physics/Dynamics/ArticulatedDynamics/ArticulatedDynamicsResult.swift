public final class ArticulatedDynamicsResult: Sendable {
    public let operation: ArticulatedDynamicsOperation
    public let originalSystem: PhysicalRigidDynamicsSystem
    public let acceleration: [Double]
    public let rightHandSide: [Double]
    public let originalResidual: ArticulatedDynamicsResidual
    public let energy: MechanicalEnergy
    /// Known recursive/preparation operation count; no measured runtime or scaling claim.
    public let recursiveOperations: Int
    public let work: NumericalWork
    public let loadWork: LoadWork
    internal init(operation: ArticulatedDynamicsOperation, originalSystem: PhysicalRigidDynamicsSystem, acceleration: [Double],
                  rightHandSide: [Double], originalResidual: ArticulatedDynamicsResidual, energy: MechanicalEnergy,
                  recursiveOperations: Int, work: NumericalWork, loadWork: LoadWork) {
        self.operation = operation; self.originalSystem = originalSystem; self.acceleration = acceleration
        self.rightHandSide = rightHandSide; self.originalResidual = originalResidual; self.energy = energy
        self.recursiveOperations = recursiveOperations; self.work = work; self.loadWork = loadWork
    }
}

/// The numerical/physical result is associated with the complete original admitted system.
public final class PhysicalDynamicsSolution: Sendable {
    public let system: PhysicalRigidDynamicsSystem
    public let acceleration: [Double]
    public let driveForce: [Double]
    public let originalPhysicalResidual: PhysicalResidual
    public let linearDiagnostics: LinearDiagnostics<Double>?
    public let work: NumericalWork
    internal init(system:PhysicalRigidDynamicsSystem,value:DynamicsSolution) {
        self.system=system;acceleration=value.acceleration;driveForce=value.driveForce
        originalPhysicalResidual=value.originalPhysicalResidual;linearDiagnostics=value.linearDiagnostics;work=value.work
    }
}

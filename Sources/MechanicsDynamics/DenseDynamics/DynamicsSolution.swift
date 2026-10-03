import MechanicsNumerics
public struct DynamicsSolution: Sendable {
    public let acceleration: [Double]
    public let driveForce: [Double]
    public let originalPhysicalResidual: PhysicalResidual
    public let linearDiagnostics: LinearDiagnostics<Double>?
    public let work: NumericalWork
    internal init(acceleration: [Double], driveForce: [Double], originalPhysicalResidual: PhysicalResidual,
                  linearDiagnostics: LinearDiagnostics<Double>?, work: NumericalWork) {
        self.acceleration = acceleration; self.driveForce = driveForce; self.originalPhysicalResidual = originalPhysicalResidual
        self.linearDiagnostics = linearDiagnostics; self.work = work
    }
}

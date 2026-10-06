/// Publication belongs to the checked evaluator; retaining input binds the original source.
public struct AffineRigidGravityResponse: Sendable {
    public let input: AffineRigidGravityInput
    public let centerOfMassWorld: Vector3
    public let centerOfMassVelocityWorld: Vector3
    public let force: Vector3
    public let torqueAtCenterOfMass: Vector3
    public let wrenchAtBodyOrigin: SpatialWrench
    public let potentialEnergy: Double
    public let diagnostics: AffineRigidGravityDiagnostics

    internal init(input: AffineRigidGravityInput, centerOfMassWorld: Vector3,
                  centerOfMassVelocityWorld: Vector3, force: Vector3, torqueAtCenterOfMass: Vector3,
                  wrenchAtBodyOrigin: SpatialWrench, potentialEnergy: Double, diagnostics: AffineRigidGravityDiagnostics) {
        self.input = input; self.centerOfMassWorld = centerOfMassWorld
        self.centerOfMassVelocityWorld = centerOfMassVelocityWorld; self.force = force
        self.torqueAtCenterOfMass = torqueAtCenterOfMass; self.wrenchAtBodyOrigin = wrenchAtBodyOrigin
        self.potentialEnergy = potentialEnergy; self.diagnostics = diagnostics
    }
}

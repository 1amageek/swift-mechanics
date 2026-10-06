/// Owned dense row-major operators in the plate's five-DOF local coordinates.
public struct ShellAssembly: Sendable {
    public let plate: RectangularShellPlate
    public let massForm: ShellMassForm
    public let internalForce: [Double]
    public let tangent: [Double]
    public let mass: [Double]
    public let damping: [Double]
    public let dampingForce: [Double]
    public let storedEnergy: Double
    public let dissipatedPower: Double
    public let totalReferenceMass: Double
    public let totalReferenceRotaryInertia: Double
    public let numericalWork: NumericalWork

    internal init(plate: RectangularShellPlate, massForm: ShellMassForm, internalForce: [Double], tangent: [Double],
                  mass: [Double], damping: [Double], dampingForce: [Double], storedEnergy: Double,
                  dissipatedPower: Double, totalReferenceMass: Double, totalReferenceRotaryInertia: Double,
                  numericalWork: NumericalWork) {
        self.plate = plate; self.massForm = massForm; self.internalForce = internalForce; self.tangent = tangent
        self.mass = mass; self.damping = damping; self.dampingForce = dampingForce
        self.storedEnergy = storedEnergy; self.dissipatedPower = dissipatedPower
        self.totalReferenceMass = totalReferenceMass; self.totalReferenceRotaryInertia = totalReferenceRotaryInertia
        self.numericalWork = numericalWork
    }
}

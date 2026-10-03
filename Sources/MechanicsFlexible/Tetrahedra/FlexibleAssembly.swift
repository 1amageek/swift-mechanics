import MechanicsNumerics
import MechanicsModel
public struct FlexibleAssembly: Sendable {
    public let frame: EntityID
    public let meshRevision: UInt64
    public let nodeIdentifiers: [UInt64]
    public let coordinateCount: Int
    public let internalForce: [Double]
    public let tangent: [Double]
    public let mass: [Double]
    public let damping: [Double]
    public let dampingForce: [Double]
    public let storedEnergy: Double
    public let dissipatedPower: Double
    public let totalReferenceMass: Double
    public let massForm: FlexibleMassForm
    public let numericalWork: NumericalWork
    public let constitutiveWork: ConstitutiveCallWork
}

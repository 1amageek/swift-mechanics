import MechanicsNumerics
import MechanicsContactLaws
import MechanicsComplementarity
public struct ContactResponseSolution: Sendable {
    public let endpointVelocity: [Double]
    public let generalizedContactForce: [Double]
    public let effectiveMassInverse: [Double]
    public let observations: [ContactObservation]
    public let originalPhysicalResidual: ContactPhysicalEvidence
    public let actualPower: Double, virtualPower: Double, prescribedPower: Double
    public let effectiveMassRank: Int?
    public let uniqueCompliantForce: Bool
    public let numericalDiagnostics: ComplementarityDiagnostics
    public let responseWork: NumericalWork, dynamicsWork: NumericalWork, coneWork: NumericalWork
    public let lawWork: ContactWork
}

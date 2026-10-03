import MechanicsFlexible
import MechanicsNumerics
public struct BeamBucklingResult: Sendable {
    public let assembly: BeamAssembly
    public let retainedCoordinates: [Int]
    /// Lowest conservative straight-branch bifurcation load in N.
    public let criticalLoad: Double
    /// Retained physical coordinates normalized by phi^T G phi=1.
    public let mode: [Double]
    public let maximumOriginalResidual: Double
    public let work: NumericalWork
}

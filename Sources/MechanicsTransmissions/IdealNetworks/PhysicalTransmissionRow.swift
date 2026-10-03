import MechanicsCore

public struct PhysicalTransmissionRow: Sendable {
    public let id: UInt64
    public let coefficients: [Double]
    public let phase: Double
    public let phaseScale: Double
    public let phaseDimension: PhysicalDimension
    internal init(id: UInt64, coefficients: [Double], phase: Double, phaseScale: Double, phaseDimension: PhysicalDimension) {
        self.id=id; self.coefficients=coefficients; self.phase=phase; self.phaseScale=phaseScale; self.phaseDimension=phaseDimension
    }
}

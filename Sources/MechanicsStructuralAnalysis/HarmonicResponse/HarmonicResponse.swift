import MechanicsCore
import MechanicsNumerics
public struct HarmonicResponse: Sendable {
    public let binding: StructuralBinding
    public let excitation: HarmonicExcitation
    public let coordinates: [StructuralComplex]
    public let outputs: [StructuralComplex]
    public let maximumOriginalResidual: Double
    public let maximumNormalizedAmplitude: Double
    public let work: NumericalWork
}

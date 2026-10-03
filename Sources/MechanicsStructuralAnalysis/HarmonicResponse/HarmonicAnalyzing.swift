import MechanicsNumerics
public protocol HarmonicAnalyzing: Sendable {
    func response(_ pencil: StructuralPencil, expectedBinding: StructuralBinding, excitation: HarmonicExcitation,
                  linearTolerance: LinearTolerance<Double>, policy: StructuralPolicy, work: inout NumericalWork) throws(StructuralError) -> HarmonicResponse
}

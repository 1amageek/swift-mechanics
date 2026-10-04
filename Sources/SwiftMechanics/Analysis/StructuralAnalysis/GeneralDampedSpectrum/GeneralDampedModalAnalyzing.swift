public protocol GeneralDampedModalAnalyzing: Sendable {
    func modes(_ pencil: StructuralPencil, expectedBinding: StructuralBinding, policy: StructuralPolicy,
               spectrumPolicy: ComplexSpectrumPolicy, work: inout NumericalWork) throws(GeneralDampedSpectrumFailure) -> GeneralDampedModalResult
}

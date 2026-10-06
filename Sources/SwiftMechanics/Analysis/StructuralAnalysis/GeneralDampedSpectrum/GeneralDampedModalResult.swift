public struct GeneralDampedModalResult: Sendable {
    public let binding: StructuralBinding
    public let poles: [SpectrumComplex]
    /// Mode-major displacement entries: modes[root*coordinateCount+coordinate].
    public let modes: [SpectrumComplex]
    public let maximumOriginalQuadraticResidual: Double
    public let maximumMassNormalizationError: Double
    public let work: NumericalWork
    internal init(binding:StructuralBinding,poles:[SpectrumComplex],modes:[SpectrumComplex],residual:Double,massError:Double,work:NumericalWork) {
        self.binding=binding;self.poles=poles;self.modes=modes
        maximumOriginalQuadraticResidual=residual;maximumMassNormalizationError=massError;self.work=work
    }
}

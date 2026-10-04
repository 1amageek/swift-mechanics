public protocol ComplexSpectralSolving: Sendable {
    func solve(_ matrix: ComplexSpectralMatrix, policy: ComplexSpectrumPolicy,
               work: inout NumericalWork) throws(ComplexSpectrumError) -> ComplexSpectrumResult
}

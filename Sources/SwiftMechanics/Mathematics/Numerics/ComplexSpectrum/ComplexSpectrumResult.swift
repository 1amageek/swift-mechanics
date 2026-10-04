public struct ComplexSpectrumResult: Sendable {
    public let dimension: Int
    public let eigenvalues: [SpectrumComplex]
    /// Mode-major entries: eigenvectors[mode*dimension+coordinate].
    public let eigenvectors: [SpectrumComplex]
    public let maximumOriginalResidual: Double
    public let work: NumericalWork
    public init(dimension: Int, eigenvalues: [SpectrumComplex], eigenvectors: [SpectrumComplex], maximumOriginalResidual: Double, work: NumericalWork) {
        self.dimension=dimension;self.eigenvalues=eigenvalues;self.eigenvectors=eigenvectors
        self.maximumOriginalResidual=maximumOriginalResidual;self.work=work
    }
}

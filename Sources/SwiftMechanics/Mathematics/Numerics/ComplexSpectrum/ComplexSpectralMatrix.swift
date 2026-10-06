/// Immutable row-major complex matrix; the spectral operation owns admission.
public struct ComplexSpectralMatrix: Sendable {
    public let dimension: Int
    public let entries: [SpectrumComplex]
    public init(dimension: Int, entries: [SpectrumComplex]) { self.dimension=dimension; self.entries=entries }
}

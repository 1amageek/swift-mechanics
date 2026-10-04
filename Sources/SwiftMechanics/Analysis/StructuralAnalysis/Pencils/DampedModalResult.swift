public struct DampedModalResult: Sendable {
    public let modes: ModalResult
    public let firstPoles: [StructuralComplex]
    public let secondPoles: [StructuralComplex]
    public let maximumOriginalQuadraticResidual: Double
    public let work: NumericalWork
}

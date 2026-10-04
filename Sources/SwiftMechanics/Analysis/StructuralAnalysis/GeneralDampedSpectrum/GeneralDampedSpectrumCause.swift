public enum GeneralDampedSpectrumCause: Error, Sendable {
    case structural(StructuralError)
    case numerical(NumericalError)
    case spectral(ComplexSpectrumError)
    case invalidSupplierLedger, invalidSupplierOutput
    case residualRejected(value: Double, threshold: Double)
}

public enum ModalReductionError: Error, Sendable {
    case invalidInput, capacityExceeded, staleBinding, cancelled, nonFiniteResult
    case invalidBasis, unstablePencil, outsideEnvelope, unsupportedSource
    case dimensionMismatch
    case residualRejected(full: Double, projected: Double)
    case interfacePowerRejected(Double)
    case referenceRejected(Double)
    case structural(StructuralError)
    case numerical(NumericalError, failedSupplierWorkUnavailable: Bool)
    case material(MaterialError)
    case core(CoreError)
    case constitutive(FlexibleError)
    case field(FieldOutputError)
}

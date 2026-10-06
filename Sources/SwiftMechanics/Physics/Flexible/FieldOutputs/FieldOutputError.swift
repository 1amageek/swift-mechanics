public enum FieldOutputError: Error, Sendable {
    case invalidInput, invalidLocation, duplicateSelection, mixedMaterials
    case capacityExceeded, constitutiveCallLimit, cancelled, nonFinite
    case staleSource, staleGeometry, staleLayout, frameMismatch
    case invertedCell(UInt64), physicalResidual
    case unsupportedStressMeasure, unsupportedProjection
    case core(CoreError), material(MaterialError), numerical(NumericalError), flexible(FlexibleError)
}

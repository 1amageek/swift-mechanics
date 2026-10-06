public enum HydroelasticError: Error, Sendable {
    case invalidInput, invalidLayout, missingPressureField, missingCell(UInt64)
    case staleRepresentation, frameMismatch, sampleMismatch, incompatibleMaterial
    case invertedCell(UInt64), ambiguousPressureVolume, boundaryDegeneracy
    case capacityExceeded, cancelled, nonFiniteResult, residualRejected
    case unsupportedWholeMesh, unsupportedSurface, unsupportedEvolution
    case core(CoreError), numerical(NumericalError)
}

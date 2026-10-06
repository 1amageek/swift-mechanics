public enum SpatialBeamError: Error, Equatable, Sendable {
    case invalidInput(parameter: String)
    case outsideDomain(measure: String, value: Double, limit: Double)
    case unsupportedFiniteRotation
    case unsupportedResolvedSectionStress
    case capacityExceeded
    case cancelled
    case nonFiniteResult
    case inconsistentOperator(measure: String)
    case core(CoreError)
    case material(MaterialError)
    case numerical(NumericalError)
}

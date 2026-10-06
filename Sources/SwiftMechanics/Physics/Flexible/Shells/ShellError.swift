public enum ShellError: Error, Equatable, Sendable {
    case invalidParameter(name: String)
    case invalidLayout
    case staleSource
    case frameMismatch
    case degenerateGeometry
    case invertedGeometry(cell: Int)
    case unsupportedFormulation
    case outsideLinearDomain(cell: Int)
    case capacityExceeded
    case nonFiniteResult
    case cancelled
    case core(CoreError)
    case material(MaterialError)
    case numerical(NumericalError)
}

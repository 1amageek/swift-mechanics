public enum NonlinearTransmissionError: Error, Equatable, Sendable {
    case invalidParameter(name: String)
    case invalidInput(name: String)
    case outsideInputDomain(value: Double, minimum: Double, maximum: Double)
    case impossibleClosure
    case singularClosure
    case singularInverse(derivative: Double, minimumAbsoluteDerivative: Double)
    case nonFiniteResult(operation: String)
}

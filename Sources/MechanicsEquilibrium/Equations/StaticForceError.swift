import MechanicsNumerics
public enum StaticForceError: Error, Equatable, Sendable {
    case invalidInput, outsideDomain, nonFiniteResult
    case numerical(NumericalError)
}

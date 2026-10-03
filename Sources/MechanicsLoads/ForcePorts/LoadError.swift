import MechanicsCore
public enum LoadError: Error, Equatable, Sendable {
    case invalidInput
    case nonFiniteResult
    case outsideDomain
    case frameMismatch
    case invalidShape
    case unsupportedDomain
    case degenerateRoute
    case invalidPassiveLaw
    case derivativeMismatch
    case missingEnergy
    case providerFailure(Int)
    case providerChanged
    case workExhausted
    case capacityExceeded
    case cancelled
    case core(CoreError)
}
internal func loadCore<T>(_ body: () throws(CoreError) -> T) throws(LoadError) -> T {
    do { return try body() } catch { throw .core(error) }
}
internal func loadFinite(_ value: Double) throws(LoadError) -> Double {
    guard value.isFinite else { throw .nonFiniteResult }
    return value
}

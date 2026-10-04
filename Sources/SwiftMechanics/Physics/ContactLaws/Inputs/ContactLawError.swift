public enum ContactLawError: Error, Equatable, Sendable {
    case core(CoreError)
    case invalidMaterial, invalidIdentity, invalidInput, invalidPolicy, frameMismatch
    case staleHistory, staleMaterial, invalidOverrideOrder, incompatibleLossPolicy, incompatibleFriction
    case normalDomain, arithmeticFailure, sequenceOverflow
    case resourceLimit(resource: ContactResource, limit: Int)
    case cancelled
    case coneResidual(value: Double, threshold: Double)
    case energyResidual(value: Double, threshold: Double)
    case powerResidual(value: Double, threshold: Double)
}
internal func contactFinite(_ value: Double) throws(ContactLawError) -> Double {
    guard value.isFinite else { throw .arithmeticFailure }; return value
}
internal func contactCore<T>(_ operation: () throws(CoreError) -> T) throws(ContactLawError) -> T {
    do { return try operation() } catch { throw .core(error) }
}

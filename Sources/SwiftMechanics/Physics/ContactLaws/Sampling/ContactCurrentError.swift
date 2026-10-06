public enum ContactCurrentError: Error, Equatable, Sendable {
    case law(ContactLawError)
    case unloadedBristles
    case disabledFrictionBristles
    case inadmissibleAcceptedTraction(utilization: Double, threshold: Double)
    case ratePowerResidual(value: Double, threshold: Double)
}

internal func contactCurrentLaw<Value>(_ operation: () throws(ContactLawError) -> Value) throws(ContactCurrentError) -> Value {
    do { return try operation() } catch { throw .law(error) }
}

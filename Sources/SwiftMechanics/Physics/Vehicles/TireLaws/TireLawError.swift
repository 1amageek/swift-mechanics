public enum TireLawError: Error, Equatable, Sendable {
    case invalidInput
    case invalidCalibration
    case invalidPolicy
    case calibrationMismatch
    case frameMismatch
    case outsideCalibratedDomain
    case lowSpeedDomain
    case contactGeometryMismatch
    case nonFiniteResult
    case physicalAcceptanceFailed
    case core(CoreError)
    case load(LoadError)
}

internal func tireCore<Value>(_ body: () throws(CoreError) -> Value) throws(TireLawError) -> Value {
    do { return try body() } catch { throw .core(error) }
}

internal func tireLoad<Value>(_ body: () throws(LoadError) -> Value) throws(TireLawError) -> Value {
    do { return try body() } catch { throw .load(error) }
}

internal func tireFinite(_ value: Double) throws(TireLawError) -> Double {
    guard value.isFinite else { throw .nonFiniteResult }
    return value
}

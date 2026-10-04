
public enum MaterialError: Error, Equatable, Sendable {
    case invalidParameter(name: String)
    case outsideDomain(measure: String, value: Double, limit: Double)
    case nonFiniteResult(operation: String)
    case incompatibleHistory
    case nonConvergence(residual: Double, tolerance: Double)
    case core(CoreError)
}

internal func materialCore<Value>(_ body: () throws(CoreError) -> Value) throws(MaterialError) -> Value {
    do { return try body() } catch { throw .core(error) }
}

internal func materialFinite(_ value: Double, operation: String) throws(MaterialError) -> Double {
    guard value.isFinite else { throw .nonFiniteResult(operation: operation) }
    return value
}

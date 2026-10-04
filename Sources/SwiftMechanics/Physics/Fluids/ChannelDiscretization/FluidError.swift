public enum FluidError: Error, Equatable, Sendable {
    case invalidInput, domain, capacity, staleBinding, nonfinite, cancelled, originalResidual
    case numerical(NumericalError, failedSupplierWorkUnavailable: Bool)
    case runtime(RuntimeFailureCode)
}
internal func fluidNumerics<T>(_ body: () throws(NumericalError) -> T) throws(FluidError) -> T {
    do { return try body() } catch { throw .numerical(error, failedSupplierWorkUnavailable: false) }
}
internal func fluidFinite(_ value: Double) throws(FluidError) -> Double {
    guard value.isFinite else { throw .nonfinite }; return value
}

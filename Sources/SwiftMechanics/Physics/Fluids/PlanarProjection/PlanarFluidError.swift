public enum PlanarFluidError: Error, Equatable, Sendable {
    case invalidInput, domain, capacity, staleBinding, stability, originalResidual, nonfinite, cancelled
    case numerical(NumericalError, failedSupplierWorkUnavailable: Bool)
}
internal func planarNumerics<T>(_ body: () throws(NumericalError)->T) throws(PlanarFluidError)->T {
    do { return try body() } catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
}
internal func planarFinite(_ value:Double) throws(PlanarFluidError)->Double {
    guard value.isFinite else { throw .nonfinite };return value
}
internal func planarResidual(_ value:Double,scale:Double,absolute:Double,relative:Double) throws(PlanarFluidError) {
    let bound=try planarFinite(absolute+relative*scale)
    guard value.isFinite,scale.isFinite,scale >= 0,abs(value) <= bound else { throw .originalResidual }
}

public enum SpatialFluidError: Error, Equatable, Sendable {
    case invalidInput, domain, capacity, staleBinding, stability, originalResidual, nonfinite, cancelled
    case numerical(NumericalError, failedSupplierWorkUnavailable: Bool)
}
internal func spatialNumerics<T>(_ body: () throws(NumericalError)->T) throws(SpatialFluidError)->T {
    do { return try body() } catch { throw .numerical(error,failedSupplierWorkUnavailable:false) }
}
internal func spatialFinite(_ value:Double) throws(SpatialFluidError)->Double {
    guard value.isFinite else { throw .nonfinite };return value
}
internal func spatialResidual(_ value:Double,scale:Double,absolute:Double,relative:Double) throws(SpatialFluidError) {
    let bound=try spatialFinite(absolute+relative*scale)
    guard value.isFinite,scale.isFinite,scale >= 0,abs(value) <= bound else { throw .originalResidual }
}

public enum TerrainLawError: Error, Equatable, Sendable {
    case invalidInput, invalidGrid, invalidCalibration, invalidPolicy
    case outsideGrid, cellLimit, staleSource, staleTime, changingFootprint
    case initiallyLoadedState, outsideCalibratedDomain, nonFiniteResult
    case sequenceOverflow, physicalAcceptanceFailed, seriesExhausted
    case core(CoreError)
    case load(LoadError)
}

internal func terrainCore<Value>(_ body: () throws(CoreError) -> Value) throws(TerrainLawError) -> Value {
    do { return try body() } catch { throw .core(error) }
}
internal func terrainLoad<Value>(_ body: () throws(LoadError) -> Value) throws(TerrainLawError) -> Value {
    do { return try body() } catch { throw .load(error) }
}
internal func terrainFinite(_ value: Double) throws(TerrainLawError) -> Double {
    guard value.isFinite else { throw .nonFiniteResult }; return value
}
internal func terrainCharge(_ text: String, work: inout LoadWork) throws(TerrainLawError) {
    for _ in text.utf8 { try terrainLoad { () throws(LoadError) in try work.charge(1) } }
}
internal func terrainReserve(base: Int, perCell: Int, cells: Int, work: inout LoadWork) throws(TerrainLawError) {
    let slots = try terrainLoad { () throws(LoadError) in try LoadWork.sum(base, LoadWork.product(perCell, cells)) }
    try terrainLoad { () throws(LoadError) in try work.reserve(scalars: slots) }
}

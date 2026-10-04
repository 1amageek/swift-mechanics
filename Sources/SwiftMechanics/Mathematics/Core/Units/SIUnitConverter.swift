public struct SIUnitConverter: UnitConverting, Sendable {
    public init() {}

    public func convert(_ value: Double, from source: UnitDefinition, to destination: UnitDefinition) throws(CoreError) -> Double {
        guard value.isFinite else { throw .nonFiniteInput }
        guard source.dimension == destination.dimension else { throw .dimensionMismatch }
        let canonical = value * source.scale + source.offset
        guard canonical.isFinite else { throw .nonFiniteResult }
        let result = (canonical - destination.offset) / destination.scale
        guard result.isFinite else { throw .nonFiniteResult }
        return result
    }
}

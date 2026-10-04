public struct UnitDefinition: Equatable, Sendable {
    public let symbol: String
    public let dimension: PhysicalDimension
    public let scale: Double
    public let offset: Double

    public init(symbol: String, dimension: PhysicalDimension, scale: Double, offset: Double = 0) throws(CoreError) {
        guard scale.isFinite, scale > 0 else { throw .invalidUnitScale }
        guard offset.isFinite, offset == 0 || dimension == .temperature else { throw .invalidUnitOffset }
        self.init(validatedSymbol: symbol, dimension: dimension, scale: scale, offset: offset)
    }

    // Predefined constants and the validated public initializer are the only callers.
    internal init(validatedSymbol symbol: String, dimension: PhysicalDimension, scale: Double, offset: Double = 0) {
        self.symbol = symbol
        self.dimension = dimension
        self.scale = scale
        self.offset = offset
    }
}

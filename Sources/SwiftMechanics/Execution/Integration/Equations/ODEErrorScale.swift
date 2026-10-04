
public struct ODEErrorScale: Equatable, Sendable {
    public let dimension: PhysicalDimension
    public let absoluteSI: Double
    public let relative: Double
    public init(dimension: PhysicalDimension, absoluteSI: Double, relative: Double) throws(RuntimeFailure) {
        guard absoluteSI.isFinite, absoluteSI > 0, relative.isFinite, relative >= 0 else { throw RuntimeFailure(.invalidInput, message: "Error scale must have positive finite SI absolute and nonnegative relative tolerance.") }
        self.dimension = dimension; self.absoluteSI = absoluteSI; self.relative = relative
    }
}

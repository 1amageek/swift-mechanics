public struct LinearEstimatorCoordinate: Equatable, Sendable {
    public let identity: String
    public let frame: String
    public let dimension: PhysicalDimension
    public let normalizationSI: Double
    public init(identity: String, frame: String, dimension: PhysicalDimension, normalizationSI: Double) {
        self.identity = identity; self.frame = frame; self.dimension = dimension; self.normalizationSI = normalizationSI
    }
}

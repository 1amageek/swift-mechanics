public struct LinearEstimatorInput: Sendable {
    public let source: ModelStamp
    public let filterIdentity: String
    public let filterRevision: UInt64
    public let coordinates: [LinearEstimatorCoordinate]
    public let intervalStartSeconds: Double
    public let intervalEndSeconds: Double
    public let normalizedValues: [Double]
    public init(source: ModelStamp, filterIdentity: String, filterRevision: UInt64, coordinates: [LinearEstimatorCoordinate],
                intervalStartSeconds: Double, intervalEndSeconds: Double, normalizedValues: [Double]) {
        self.source = source; self.filterIdentity = filterIdentity; self.filterRevision = filterRevision
        self.coordinates = coordinates; self.intervalStartSeconds = intervalStartSeconds
        self.intervalEndSeconds = intervalEndSeconds; self.normalizedValues = normalizedValues
    }
}

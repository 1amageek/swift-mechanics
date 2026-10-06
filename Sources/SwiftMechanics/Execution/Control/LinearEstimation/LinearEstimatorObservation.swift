public struct LinearEstimatorObservation: Sendable {
    public let source: ModelStamp
    public let filterIdentity: String
    public let filterRevision: UInt64
    public let coordinates: [LinearEstimatorCoordinate]
    public let sequence: UInt64
    public let sampleTimeSeconds: Double
    public let deliveryTimeSeconds: Double
    public let normalizedValues: [Double]
    public init(source: ModelStamp, filterIdentity: String, filterRevision: UInt64, coordinates: [LinearEstimatorCoordinate],
                sequence: UInt64, sampleTimeSeconds: Double, deliveryTimeSeconds: Double, normalizedValues: [Double]) {
        self.source = source; self.filterIdentity = filterIdentity; self.filterRevision = filterRevision
        self.coordinates = coordinates; self.sequence = sequence; self.sampleTimeSeconds = sampleTimeSeconds
        self.deliveryTimeSeconds = deliveryTimeSeconds; self.normalizedValues = normalizedValues
    }
}

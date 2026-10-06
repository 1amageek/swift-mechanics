public struct LinearQuadraticCommand: Sendable {
    public let systemIdentity: String
    public let samplePeriodSeconds: Double
    public let inputDimensions: [PhysicalDimension]
    public let unconstrainedInput: [Double]
    public let appliedInput: [Double]
    public let saturated: [Bool]
    /// Saturation makes the applied command differ from the certified linear closed loop.
    public var followsCertifiedLinearFeedback: Bool { !saturated.contains(true) }
}

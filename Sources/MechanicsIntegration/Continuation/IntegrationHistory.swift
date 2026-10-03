public struct IntegrationHistory: Equatable, Sendable {
    public let acceptedTime: Double
    public let acceptedPoint: [Double]
    public let nextStep: Double
    public let acceptedSteps: UInt64
    public let normalizedError: Double?
    internal init(time: Double, point: [Double], nextStep: Double, steps: UInt64, error: Double?) {
        acceptedTime = time; acceptedPoint = point; self.nextStep = nextStep; acceptedSteps = steps; normalizedError = error
    }
}

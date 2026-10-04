public struct FixedActiveNonlinearProblem: Sendable {
    public let provider: any SmoothNonlinearProgramProviding<Double>
    public let lowerBounds: [Double], upperBounds: [Double], activeInequalities: [Int]
    public let initialPoint: [Double], initialEqualityMultipliers: [Double], initialActiveMultipliers: [Double]
    public init(provider: any SmoothNonlinearProgramProviding<Double>,lowerBounds: [Double],upperBounds: [Double],activeInequalities: [Int],
        initialPoint: [Double],initialEqualityMultipliers: [Double],initialActiveMultipliers: [Double]) {
        self.provider=provider; self.lowerBounds=lowerBounds; self.upperBounds=upperBounds; self.activeInequalities=activeInequalities
        self.initialPoint=initialPoint; self.initialEqualityMultipliers=initialEqualityMultipliers; self.initialActiveMultipliers=initialActiveMultipliers
    }
}

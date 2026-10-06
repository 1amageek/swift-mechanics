public struct DiscreteControlSystem: Sendable {
    public let identity: String
    public let samplePeriodSeconds: Double
    public let stateDimensions: [PhysicalDimension]
    public let inputDimensions: [PhysicalDimension]
    public let stateScales: [Double]
    public let inputScales: [Double]
    /// Row-major normalized-coordinate transition and input matrices.
    public let stateMatrix: [Double]
    public let inputMatrix: [Double]
    public let provenance: DiscreteControlProvenance
    public var stateCount: Int { stateDimensions.count }
    public var inputCount: Int { inputDimensions.count }
    internal init(identity: String, samplePeriodSeconds: Double, stateDimensions: [PhysicalDimension], inputDimensions: [PhysicalDimension],
                  stateScales: [Double], inputScales: [Double], stateMatrix: [Double], inputMatrix: [Double], provenance: DiscreteControlProvenance) {
        self.identity = identity; self.samplePeriodSeconds = samplePeriodSeconds
        self.stateDimensions = stateDimensions; self.inputDimensions = inputDimensions
        self.stateScales = stateScales; self.inputScales = inputScales
        self.stateMatrix = stateMatrix; self.inputMatrix = inputMatrix; self.provenance = provenance
    }
}

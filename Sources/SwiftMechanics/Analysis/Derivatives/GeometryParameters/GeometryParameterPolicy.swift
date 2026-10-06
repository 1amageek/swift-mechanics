public struct GeometryParameterPolicy: Sendable {
    public let maximumBodies: Int
    public let maximumVelocities: Int
    public let maximumParameters: Int
    public let minimumRawAxisMagnitude: Double
    public let primalTolerance: NumericalTolerance
    public let residualTolerance: NumericalTolerance
    public let jointPolicy: JointEvaluationPolicy
    public let isCancelled: @Sendable () -> Bool
    public init(maximumBodies: Int, maximumVelocities: Int, maximumParameters: Int,
                minimumRawAxisMagnitude: Double, primalTolerance: NumericalTolerance,
                residualTolerance: NumericalTolerance, jointPolicy: JointEvaluationPolicy,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(GeometryParameterError) {
        guard maximumBodies > 0, maximumVelocities >= 0, maximumParameters > 0,
              minimumRawAxisMagnitude.isFinite, minimumRawAxisMagnitude > 0 else { throw .invalidInput }
        self.maximumBodies = maximumBodies; self.maximumVelocities = maximumVelocities; self.maximumParameters = maximumParameters
        self.minimumRawAxisMagnitude = minimumRawAxisMagnitude; self.primalTolerance = primalTolerance
        self.residualTolerance = residualTolerance; self.jointPolicy = jointPolicy; self.isCancelled = isCancelled
    }
}

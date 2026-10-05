public struct TaskSpacePolicy: Sendable {
    public let maximumVelocities: Int
    public let maximumBodies: Int
    public let dynamics: DynamicsSolvePolicy
    public let taskLinearTolerance: LinearTolerance<Double>
    public let taskAccelerationTolerance: NumericalTolerance
    public let secondaryLeakTolerance: NumericalTolerance
    public let powerTolerance: NumericalTolerance
    /// Dimensionless generalized acceleration agreement after q/time scale normalization.
    public let replayTolerance: NumericalTolerance
    public let lengthScaleMeters: Double
    public let rankRelativeTolerance: Double
    public let singularity: TaskSpaceSingularityPolicy
    public let isCancelled: @Sendable () -> Bool
    public init(maximumVelocities: Int, maximumBodies: Int, dynamics: DynamicsSolvePolicy,
                taskLinearTolerance: LinearTolerance<Double>, taskAccelerationTolerance: NumericalTolerance,
                secondaryLeakTolerance: NumericalTolerance, powerTolerance: NumericalTolerance, replayTolerance: NumericalTolerance,
                lengthScaleMeters: Double, rankRelativeTolerance: Double,
                singularity: TaskSpaceSingularityPolicy, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(TaskSpaceFailure) {
        guard maximumVelocities > 0, maximumBodies > 0, lengthScaleMeters.isFinite, lengthScaleMeters > 0,
              rankRelativeTolerance.isFinite, rankRelativeTolerance > 0, rankRelativeTolerance < 1 else {
            throw TaskSpaceFailure(.invalidInput)
        }
        if case .damped(let lambda) = singularity {
            guard lambda.isFinite, lambda > 0, (lambda * lambda).isFinite, lambda * lambda > 0 else {
                throw TaskSpaceFailure(.invalidInput)
            }
        }
        self.maximumVelocities = maximumVelocities; self.maximumBodies = maximumBodies
        self.dynamics = dynamics; self.taskLinearTolerance = taskLinearTolerance
        self.taskAccelerationTolerance = taskAccelerationTolerance; self.secondaryLeakTolerance = secondaryLeakTolerance
        self.powerTolerance = powerTolerance; self.lengthScaleMeters = lengthScaleMeters
        self.replayTolerance = replayTolerance
        self.rankRelativeTolerance = rankRelativeTolerance; self.singularity = singularity; self.isCancelled = isCancelled
    }
}

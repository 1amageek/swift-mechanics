public struct TreeReactionPolicy: Sendable {
    public let maximumBodies: Int
    public let maximumJoints: Int
    public let maximumBodyLoads: Int
    /// Positive force/torque scale in each original generalized velocity coordinate.
    public let generalizedForceScales: [Double]
    public let generalizedTolerance: NumericalTolerance
    public let forceTolerance: NumericalTolerance
    public let torqueTolerance: NumericalTolerance
    public let isCancelled: @Sendable () -> Bool
    public init(maximumBodies: Int, maximumJoints: Int, maximumBodyLoads: Int,
                generalizedForceScales: [Double], generalizedTolerance: NumericalTolerance,
                forceTolerance: NumericalTolerance, torqueTolerance: NumericalTolerance,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(ReactionPathError) {
        guard maximumBodies >= 0, maximumJoints >= 0, maximumBodyLoads >= 0,
              generalizedForceScales.allSatisfy({ $0.isFinite && $0 > 0 }) else { throw .invalidInput }
        self.maximumBodies = maximumBodies; self.maximumJoints = maximumJoints; self.maximumBodyLoads = maximumBodyLoads
        self.generalizedForceScales = generalizedForceScales; self.generalizedTolerance = generalizedTolerance
        self.forceTolerance = forceTolerance; self.torqueTolerance = torqueTolerance; self.isCancelled = isCancelled
    }
}

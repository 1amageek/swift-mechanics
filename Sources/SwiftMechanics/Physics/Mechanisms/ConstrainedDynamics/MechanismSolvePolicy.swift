
public struct MechanismSolvePolicy: Sendable {
    public let dynamics: DynamicsSolvePolicy
    public let constraints: ConstraintSolvePolicy
    public let maximumCoordinates: Int
    public let maximumRows: Int
    public let originalTolerance: Double
    public let isCancelled: @Sendable () -> Bool
    public init(dynamics: DynamicsSolvePolicy, constraints: ConstraintSolvePolicy, maximumCoordinates: Int,
                maximumRows: Int, originalTolerance: Double, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(MechanismError) {
        guard maximumCoordinates > 0, maximumRows > 0, originalTolerance.isFinite, originalTolerance >= 0,
              dynamics.energyScale == constraints.energyScale else { throw .invalidInput }
        self.dynamics=dynamics; self.constraints=constraints; self.maximumCoordinates=maximumCoordinates
        self.maximumRows=maximumRows; self.originalTolerance=originalTolerance; self.isCancelled=isCancelled
    }
}

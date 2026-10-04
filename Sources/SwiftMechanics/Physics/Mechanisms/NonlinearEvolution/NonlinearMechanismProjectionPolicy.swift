public struct NonlinearMechanismProjectionPolicy: Sendable {
    public let position: ConstraintSolvePolicy
    public let maximumIterations: Int
    public let maximumCorrection: Double
    public init(position: ConstraintSolvePolicy, maximumIterations: Int, maximumCorrection: Double) throws(MechanismError) {
        guard maximumIterations > 0, maximumCorrection.isFinite, maximumCorrection >= 0 else { throw .invalidInput }
        self.position=position; self.maximumIterations=maximumIterations; self.maximumCorrection=maximumCorrection
    }
}

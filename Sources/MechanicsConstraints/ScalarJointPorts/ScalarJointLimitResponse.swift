public struct ScalarJointLimitResponse: Sendable {
    public let lowerGap: Double
    public let upperGap: Double
    public let lowerJacobian: Double
    public let upperJacobian: Double
    public let lowerGapRate: Double
    public let upperGapRate: Double
    /// Nil for hard rows: dynamic reactions belong to the constrained dynamics solve.
    public let compliantEffort: Double?
    public let potentialEnergy: Double?
    public let dissipativePower: Double?
    public init(lowerGap: Double, upperGap: Double, lowerJacobian: Double, upperJacobian: Double, lowerGapRate: Double, upperGapRate: Double,
                compliantEffort: Double?, potentialEnergy: Double?, dissipativePower: Double?) {
        self.lowerGap=lowerGap; self.upperGap=upperGap; self.lowerJacobian=lowerJacobian; self.upperJacobian=upperJacobian
        self.lowerGapRate=lowerGapRate; self.upperGapRate=upperGapRate; self.compliantEffort=compliantEffort
        self.potentialEnergy=potentialEnergy; self.dissipativePower=dissipativePower
    }
}

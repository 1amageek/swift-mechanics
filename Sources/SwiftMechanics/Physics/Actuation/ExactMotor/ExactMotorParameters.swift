public struct ExactMotorParameters: Equatable, Sendable {
    public let inductance: Double, resistance: Double, reciprocalConstant: Double, damping: Double
    public let maximumVoltage: Double, maximumCurrent: Double, maximumSpeed: Double
    public init(inductance: Double, resistance: Double, reciprocalConstant: Double, damping: Double,
                maximumVoltage: Double, maximumCurrent: Double, maximumSpeed: Double) throws(ActuationError) {
        guard inductance.isFinite, resistance.isFinite, reciprocalConstant.isFinite, damping.isFinite,
              maximumVoltage.isFinite, maximumCurrent.isFinite, maximumSpeed.isFinite,
              inductance > 0, resistance >= 0, reciprocalConstant > 0, damping >= 0,
              maximumVoltage > 0, maximumCurrent > 0, maximumSpeed > 0,
              (resistance / inductance).isFinite else { throw .invalidLaw }
        self.inductance = inductance; self.resistance = resistance; self.reciprocalConstant = reciprocalConstant
        self.damping = damping; self.maximumVoltage = maximumVoltage
        self.maximumCurrent = maximumCurrent; self.maximumSpeed = maximumSpeed
    }
}

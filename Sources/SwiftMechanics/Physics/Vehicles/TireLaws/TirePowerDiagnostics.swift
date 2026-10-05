public struct TirePowerDiagnostics: Equatable, Sendable {
    public let wheelMechanicalPower: Double
    public let roadMechanicalPower: Double
    public let slipDissipationPower: Double
    public let rollingDissipationPower: Double
    public let originalPowerResidual: Double
    public let originalForceConeExcess: Double

    internal init(wheelMechanicalPower: Double, roadMechanicalPower: Double,
                  slipDissipationPower: Double, rollingDissipationPower: Double,
                  originalPowerResidual: Double, originalForceConeExcess: Double) {
        self.wheelMechanicalPower = wheelMechanicalPower; self.roadMechanicalPower = roadMechanicalPower
        self.slipDissipationPower = slipDissipationPower; self.rollingDissipationPower = rollingDissipationPower
        self.originalPowerResidual = originalPowerResidual; self.originalForceConeExcess = originalForceConeExcess
    }
}

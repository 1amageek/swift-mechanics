public struct CapstanFrictionLaw: Equatable, Sendable {
    public let wrapAngle: Double, staticCoefficient: Double, kineticCoefficient: Double
    public let maximumTension: Double, maximumSlipSpeed: Double
    public init(wrapAngle: Double, staticCoefficient: Double, kineticCoefficient: Double,
                maximumTension: Double, maximumSlipSpeed: Double) throws(ActuationError) {
        guard wrapAngle.isFinite, staticCoefficient.isFinite, kineticCoefficient.isFinite,
              maximumTension.isFinite, maximumSlipSpeed.isFinite,
              wrapAngle >= 0, staticCoefficient >= kineticCoefficient, kineticCoefficient >= 0,
              maximumTension > 0, maximumSlipSpeed > 0,
              (wrapAngle * staticCoefficient).isFinite else { throw .invalidLaw }
        self.wrapAngle = wrapAngle; self.staticCoefficient = staticCoefficient; self.kineticCoefficient = kineticCoefficient
        self.maximumTension = maximumTension; self.maximumSlipSpeed = maximumSlipSpeed
    }
}

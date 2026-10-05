public struct TireAcceptancePolicy: Equatable, Sendable {
    public let contactDistanceTolerance: Double
    public let normalSpeedTolerance: Double
    public let absolutePowerTolerance: Double
    public let referencePower: Double
    public let absoluteForceTolerance: Double
    public let referenceForce: Double
    public let relativeTolerance: Double

    public init(contactDistanceTolerance: Double, normalSpeedTolerance: Double,
                absolutePowerTolerance: Double, referencePower: Double,
                absoluteForceTolerance: Double, referenceForce: Double,
                relativeTolerance: Double) throws(TireLawError) {
        guard contactDistanceTolerance.isFinite, contactDistanceTolerance >= 0,
              normalSpeedTolerance.isFinite, normalSpeedTolerance >= 0,
              absolutePowerTolerance.isFinite, absolutePowerTolerance >= 0,
              referencePower.isFinite, referencePower > 0,
              absoluteForceTolerance.isFinite, absoluteForceTolerance >= 0,
              referenceForce.isFinite, referenceForce > 0,
              relativeTolerance.isFinite, relativeTolerance >= 0, relativeTolerance < 1 else {
            throw .invalidPolicy
        }
        self.contactDistanceTolerance = contactDistanceTolerance; self.normalSpeedTolerance = normalSpeedTolerance
        self.absolutePowerTolerance = absolutePowerTolerance; self.referencePower = referencePower
        self.absoluteForceTolerance = absoluteForceTolerance; self.referenceForce = referenceForce
        self.relativeTolerance = relativeTolerance
    }
}

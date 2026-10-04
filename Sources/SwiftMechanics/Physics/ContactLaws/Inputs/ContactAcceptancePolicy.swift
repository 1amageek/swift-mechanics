public struct ContactAcceptancePolicy: Sendable {
    public let absoluteEnergyTolerance: Double
    public let absolutePowerTolerance: Double
    public let relativeTolerance: Double
    public let coneTolerance: Double
    public let referenceEnergy: Double
    public let referencePower: Double
    public init(absoluteEnergyTolerance: Double, absolutePowerTolerance: Double, relativeTolerance: Double,
                referenceEnergy: Double, referencePower: Double, coneTolerance: Double) throws(ContactLawError) {
        guard absoluteEnergyTolerance.isFinite, absoluteEnergyTolerance >= 0,
              absolutePowerTolerance.isFinite, absolutePowerTolerance >= 0,
              relativeTolerance.isFinite, relativeTolerance >= 0, coneTolerance.isFinite, coneTolerance >= 0,
              referenceEnergy.isFinite, referenceEnergy > 0, referencePower.isFinite, referencePower > 0 else { throw .invalidPolicy }
        self.absoluteEnergyTolerance=absoluteEnergyTolerance; self.absolutePowerTolerance=absolutePowerTolerance
        self.relativeTolerance=relativeTolerance; self.coneTolerance=coneTolerance; self.referenceEnergy=referenceEnergy; self.referencePower=referencePower
    }
}

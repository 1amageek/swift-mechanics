public struct ContactDerivativePolicy: Sendable {
    public let separationRadius: Double
    public let normalSpeedRadius: Double
    public let maximumIdentifierBytes: Int
    public let absolutePrimalTolerance: Double
    public let relativePrimalTolerance: Double
    public let acceptance: ContactAcceptancePolicy
    public let isCancelled: @Sendable () -> Bool
    public init(separationRadius: Double, normalSpeedRadius: Double, maximumIdentifierBytes: Int,
                absolutePrimalTolerance: Double, relativePrimalTolerance: Double,
                acceptance: ContactAcceptancePolicy, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(ContactDerivativeError) {
        guard separationRadius.isFinite, separationRadius > 0, normalSpeedRadius.isFinite, normalSpeedRadius > 0,
              maximumIdentifierBytes >= 0, absolutePrimalTolerance.isFinite, absolutePrimalTolerance >= 0,
              relativePrimalTolerance.isFinite, relativePrimalTolerance >= 0 else { throw .invalidInput }
        self.separationRadius=separationRadius; self.normalSpeedRadius=normalSpeedRadius
        self.maximumIdentifierBytes=maximumIdentifierBytes; self.absolutePrimalTolerance=absolutePrimalTolerance
        self.relativePrimalTolerance=relativePrimalTolerance; self.acceptance=acceptance; self.isCancelled=isCancelled
    }
}

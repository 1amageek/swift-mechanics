public struct ContactImpactDirection: Sendable {
    public let approachSpeed: Double
    public let incomingNormalEnergy: Double
    public init(approachSpeed: Double, incomingNormalEnergy: Double) throws(ContactDerivativeError) {
        guard approachSpeed.isFinite, incomingNormalEnergy.isFinite else { throw .invalidInput }
        self.approachSpeed=approachSpeed; self.incomingNormalEnergy=incomingNormalEnergy
    }
}

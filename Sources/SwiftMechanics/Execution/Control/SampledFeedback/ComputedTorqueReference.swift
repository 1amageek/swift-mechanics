public struct ComputedTorqueReference: Sendable {
    public let positionMeters:Double,rateMetersPerSecond:Double,accelerationMetersPerSecondSquared:Double
    public init(positionMeters:Double,rateMetersPerSecond:Double,accelerationMetersPerSecondSquared:Double) throws(ControlFailure) {
        guard positionMeters.isFinite,rateMetersPerSecond.isFinite,accelerationMetersPerSecondSquared.isFinite else { throw ControlFailure(.invalidInput,phase:"reference") }
        self.positionMeters=positionMeters;self.rateMetersPerSecond=rateMetersPerSecond;self.accelerationMetersPerSecondSquared=accelerationMetersPerSecondSquared
    }
}

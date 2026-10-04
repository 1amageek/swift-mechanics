public struct MechanismSleepPolicy: Sendable {
    public let maximumCoordinates:Int
    public let kineticEnergyThreshold:Double
    public let normalizedVelocityThreshold:Double
    public let isCancelled:@Sendable () -> Bool
    public init(maximumCoordinates:Int,kineticEnergyThreshold:Double,normalizedVelocityThreshold:Double,
                isCancelled:@escaping @Sendable () -> Bool = { false }) throws(MechanismError) {
        guard maximumCoordinates > 0,kineticEnergyThreshold.isFinite,kineticEnergyThreshold >= 0,
              normalizedVelocityThreshold.isFinite,normalizedVelocityThreshold >= 0 else { throw .invalidInput }
        self.maximumCoordinates=maximumCoordinates;self.kineticEnergyThreshold=kineticEnergyThreshold
        self.normalizedVelocityThreshold=normalizedVelocityThreshold;self.isCancelled=isCancelled
    }
}

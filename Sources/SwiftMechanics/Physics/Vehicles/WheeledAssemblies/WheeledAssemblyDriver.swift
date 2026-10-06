public struct WheeledAssemblyDriver: Equatable, Sendable {
    public let throttle, steeringAngle, rearBrake, frontBrake: Double
    public init(throttle: Double, steeringAngle: Double, rearBrake: Double, frontBrake: Double) throws(WheeledAssemblyFailure) {
        guard throttle.isFinite, abs(throttle) <= 1, steeringAngle.isFinite,
              rearBrake.isFinite, frontBrake.isFinite, (0...1).contains(rearBrake), (0...1).contains(frontBrake) else { throw .refusal(.invalidInput) }
        self.throttle=throttle; self.steeringAngle=steeringAngle; self.rearBrake=rearBrake; self.frontBrake=frontBrake
    }
}

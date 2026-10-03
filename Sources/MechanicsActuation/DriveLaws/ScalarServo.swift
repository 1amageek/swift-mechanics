public struct ScalarServo: Equatable, Sendable {
    public let binding:ActuatorBinding
    public let positionGain:Double,velocityGain:Double,integralGain:Double,integralLimit:Double
    public let effortLimit:Double,speedLimit:Double,positionDeadband:Double,velocityDeadband:Double,filterTimeConstant:Double
    public init(binding:ActuatorBinding,positionGain:Double,velocityGain:Double,integralGain:Double,integralLimit:Double,
                effortLimit:Double,speedLimit:Double,positionDeadband:Double,velocityDeadband:Double,filterTimeConstant:Double) throws(ActuationError) {
        guard binding.stateKind == .servo,
              positionGain.isFinite,velocityGain.isFinite,integralGain.isFinite,integralLimit.isFinite,effortLimit.isFinite,speedLimit.isFinite,
              positionDeadband.isFinite,velocityDeadband.isFinite,filterTimeConstant.isFinite,
              positionGain >= 0,velocityGain >= 0,integralGain >= 0,integralLimit >= 0,effortLimit > 0,speedLimit > 0,
              positionDeadband >= 0,velocityDeadband >= 0,filterTimeConstant >= 0,
              binding.stateDomain.primaryLower == -integralLimit,binding.stateDomain.primaryUpper == integralLimit else { throw .invalidLaw }
        self.binding=binding;self.positionGain=positionGain;self.velocityGain=velocityGain;self.integralGain=integralGain;self.integralLimit=integralLimit
        self.effortLimit=effortLimit;self.speedLimit=speedLimit;self.positionDeadband=positionDeadband;self.velocityDeadband=velocityDeadband;self.filterTimeConstant=filterTimeConstant
    }
}

import MechanicsLoads
public struct SelectedMuscleLaw: Equatable, Sendable {
    public let binding:ActuatorBinding
    public let maximumForce:Double,optimalLength:Double,lengthWidth:Double,maximumShorteningSpeed:Double,maximumLengtheningSpeed:Double
    public let hillCurvature:Double,eccentricGain:Double,activationTimeConstant:Double,passiveStiffness:Double,slackLength:Double
    public init(binding:ActuatorBinding,maximumForce:Double,optimalLength:Double,lengthWidth:Double,maximumShorteningSpeed:Double,maximumLengtheningSpeed:Double,
                hillCurvature:Double,eccentricGain:Double,activationTimeConstant:Double,passiveStiffness:Double,slackLength:Double) throws(ActuationError) {
        guard binding.stateKind == .muscle,binding.coordinate == .translation,
              maximumForce.isFinite,optimalLength.isFinite,lengthWidth.isFinite,maximumShorteningSpeed.isFinite,maximumLengtheningSpeed.isFinite,
              hillCurvature.isFinite,eccentricGain.isFinite,activationTimeConstant.isFinite,passiveStiffness.isFinite,slackLength.isFinite,
              maximumForce > 0,optimalLength > 0,lengthWidth > 0,lengthWidth < optimalLength,maximumShorteningSpeed > 0,maximumLengtheningSpeed > 0,
              hillCurvature > 0,eccentricGain >= 1,activationTimeConstant > 0,passiveStiffness >= 0,slackLength > 0,
              binding.stateDomain.primaryLower == 0,binding.stateDomain.primaryUpper == 1,
              binding.stateDomain.secondaryLower == 0,binding.stateDomain.secondaryUpper == 0 else { throw .invalidLaw }
        self.binding=binding;self.maximumForce=maximumForce;self.optimalLength=optimalLength;self.lengthWidth=lengthWidth
        self.maximumShorteningSpeed=maximumShorteningSpeed;self.maximumLengtheningSpeed=maximumLengtheningSpeed;self.hillCurvature=hillCurvature;self.eccentricGain=eccentricGain
        self.activationTimeConstant=activationTimeConstant;self.passiveStiffness=passiveStiffness;self.slackLength=slackLength
    }
}

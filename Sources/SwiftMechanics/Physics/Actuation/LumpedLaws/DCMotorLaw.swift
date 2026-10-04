public struct DCMotorLaw: Equatable, Sendable {
    public let binding:ActuatorBinding
    public let inductanceHenries:Double,resistanceOhms:Double,reciprocalConstant:Double,viscousDamping:Double
    public let maximumVoltage:Double,maximumCurrent:Double,maximumSpeed:Double
    public init(binding:ActuatorBinding,inductanceHenries:Double,resistanceOhms:Double,reciprocalConstant:Double,viscousDamping:Double,
                maximumVoltage:Double,maximumCurrent:Double,maximumSpeed:Double) throws(ActuationError) {
        guard binding.stateKind == .motor,binding.coordinate == .rotation,
              inductanceHenries.isFinite,resistanceOhms.isFinite,reciprocalConstant.isFinite,viscousDamping.isFinite,
              maximumVoltage.isFinite,maximumCurrent.isFinite,maximumSpeed.isFinite,
              inductanceHenries > 0,resistanceOhms >= 0,reciprocalConstant > 0,viscousDamping >= 0,maximumVoltage > 0,maximumCurrent > 0,maximumSpeed > 0,
              binding.stateDomain.primaryLower == -maximumCurrent,binding.stateDomain.primaryUpper == maximumCurrent,
              binding.stateDomain.secondaryLower == 0,binding.stateDomain.secondaryUpper == 0 else { throw .invalidLaw }
        self.binding=binding;self.inductanceHenries=inductanceHenries;self.resistanceOhms=resistanceOhms;self.reciprocalConstant=reciprocalConstant;self.viscousDamping=viscousDamping
        self.maximumVoltage=maximumVoltage;self.maximumCurrent=maximumCurrent;self.maximumSpeed=maximumSpeed
    }
}

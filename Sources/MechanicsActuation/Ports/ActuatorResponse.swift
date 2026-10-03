public struct ActuatorResponse: Equatable, Sendable {
    public let state:ActuatorState
    public let requestedEffort:Double,appliedEffort:Double,power:Double
    public let requestedInput:Double,appliedInput:Double
    public let clipped:Bool
    public let energy:ActuatorEnergy
    internal init(state:ActuatorState,requestedEffort:Double,appliedEffort:Double,power:Double,requestedInput:Double,appliedInput:Double,clipped:Bool,energy:ActuatorEnergy) throws(ActuationError) {
        guard requestedEffort.isFinite,appliedEffort.isFinite,power.isFinite,requestedInput.isFinite,appliedInput.isFinite else { throw .nonfiniteResult }
        self.state=state;self.requestedEffort=requestedEffort;self.appliedEffort=appliedEffort;self.power=power;self.requestedInput=requestedInput;self.appliedInput=appliedInput;self.clipped=clipped;self.energy=energy
    }
}

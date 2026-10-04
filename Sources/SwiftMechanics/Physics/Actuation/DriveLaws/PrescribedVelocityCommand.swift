public struct PrescribedVelocityCommand: Equatable, Sendable {
    public let binding:ActuatorBinding
    public let time:Double,requestedVelocity:Double,appliedVelocity:Double
    public let clipped:Bool
    internal init(binding:ActuatorBinding,time:Double,requestedVelocity:Double,appliedVelocity:Double) {
        self.binding=binding;self.time=time;self.requestedVelocity=requestedVelocity;self.appliedVelocity=appliedVelocity;clipped=requestedVelocity != appliedVelocity
    }
}

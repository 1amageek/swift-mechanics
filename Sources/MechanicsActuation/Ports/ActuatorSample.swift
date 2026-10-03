public struct ActuatorSample: Equatable, Sendable {
    public let binding:ActuatorBinding
    public let time:Double,position:Double,velocity:Double
    public init(binding:ActuatorBinding,time:Double,position:Double,velocity:Double) throws(ActuationError) {
        guard time.isFinite,position.isFinite,velocity.isFinite else { throw .invalidInput }
        self.binding=binding;self.time=time;self.position=position;self.velocity=velocity
    }
}

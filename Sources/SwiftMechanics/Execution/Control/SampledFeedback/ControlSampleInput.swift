public struct ControlSampleInput: Sendable {
    public enum Demand: Sendable { case servo(DriveCommand), computedTorque(ComputedTorqueReference) }
    public let encoder:JointEncoderObservation
    public let sampleTickTime:Double
    public let tick:UInt64
    public let demand:Demand
    public let commandDimension:PhysicalDimension
    public init(encoder:JointEncoderObservation,sampleTickTime:Double,tick:UInt64,demand:Demand,commandDimension:PhysicalDimension) {
        self.encoder=encoder;self.sampleTickTime=sampleTickTime;self.tick=tick;self.demand=demand;self.commandDimension=commandDimension
    }
}

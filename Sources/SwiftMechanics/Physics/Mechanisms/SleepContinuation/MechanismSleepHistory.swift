public struct MechanismSleepHistory: Equatable, Sendable {
    public let acceptedTime: Double
    public let acceptedSequence: UInt64
    public let position: [Double]
    public let velocity: [Double]
    public let drive: [Double]
    public let commandGeneration: UInt64
    public let asleep: [Bool]
    public let restSince: [Double]
    public let wakeSequence: UInt64
    /// 0 initial, 1 constant command, 2 physical impulse.
    public let lastWakeKind: UInt64
    public let lastWakeCoordinates: [Bool]
    internal init(time:Double,sequence:UInt64,q:[Double],v:[Double],drive:[Double],generation:UInt64,
                  asleep:[Bool],restSince:[Double],wakeSequence:UInt64,kind:UInt64,coordinates:[Bool]) {
        acceptedTime=time;acceptedSequence=sequence;position=q;velocity=v;self.drive=drive;commandGeneration=generation
        self.asleep=asleep;self.restSince=restSince;self.wakeSequence=wakeSequence;lastWakeKind=kind;lastWakeCoordinates=coordinates
    }
}

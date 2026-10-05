public struct IslandSleepHistory: Sendable {
    public let acceptedTime: Double
    public let acceptedSequence: UInt64
    public let position: [Double]
    public let velocity: [Double]
    public let islandIDs: [UInt64]
    public let asleep: [Bool]
    public let restSince: [Double]
    public let wakeSequence: UInt64
    public let lastWakeTime: Double
    public let lastWakeEventID: UInt64
    public let lastWakeKind: UInt64
    public let lastWakeIslands: [Bool]
    internal init(time:Double,sequence:UInt64,q:[Double],v:[Double],ids:[UInt64],asleep:[Bool],since:[Double],wakeSequence:UInt64=0,wakeTime:Double=0,eventID:UInt64=0,kind:UInt64=0,affected:[Bool]) {
        acceptedTime=time;acceptedSequence=sequence;position=q;velocity=v;islandIDs=ids;self.asleep=asleep;restSince=since
        self.wakeSequence=wakeSequence;lastWakeTime=wakeTime;lastWakeEventID=eventID;lastWakeKind=kind;lastWakeIslands=affected
    }
}

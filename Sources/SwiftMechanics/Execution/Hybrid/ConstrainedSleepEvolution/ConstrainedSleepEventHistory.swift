public struct ConstrainedSleepEventHistory: Sendable {
    public let acceptedTime:Double
    public let acceptedSequence:UInt64
    public let position:[Double]
    public let velocity:[Double]
    public let impactCount:UInt64
    public let lastImpactTime:Double
    public let lastEventID:UInt64
    public let sourceSequence:UInt64
    public let targetSequence:UInt64
    public let wakeIslandIDs:[UInt64]
    internal init(time:Double,sequence:UInt64,q:[Double],v:[Double],count:UInt64=0,lastTime:Double=0,eventID:UInt64=0,source:UInt64=0,target:UInt64=0,wake:[UInt64]=[]) {
        acceptedTime=time;acceptedSequence=sequence;position=q;velocity=v;impactCount=count;lastImpactTime=lastTime;lastEventID=eventID;sourceSequence=source;targetSequence=target;wakeIslandIDs=wake
    }
}

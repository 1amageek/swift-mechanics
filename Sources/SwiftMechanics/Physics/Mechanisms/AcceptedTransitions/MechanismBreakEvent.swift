
public struct MechanismBreakEvent: Sendable {
    public enum Metric: UInt64, Equatable, Sendable { case torque = 0, force = 1, angularImpulse = 2, linearImpulse = 3 }
    public let id:UInt64
    public let source:ModelStamp
    public let target:ModelStamp
    public let joint:EntityID
    public let connector:EntityID
    public let acceptedTime:Double
    public let metric:Metric
    public let observed:Double
    public let threshold:Double
    public init(id:UInt64,source:ModelStamp,target:ModelStamp,joint:EntityID,connector:EntityID,acceptedTime:Double,metric:Metric,observed:Double,threshold:Double,maximumMetadataBytes:Int) throws(MechanismError) {
        guard maximumMetadataBytes >= 0 else { throw .invalidInput }
        var metadata=0
        for text in [source.identity,target.identity,joint.key,connector.key] {
            for _ in text.utf8 { guard metadata < maximumMetadataBytes else { throw .capacityExceeded };metadata+=1 }
        }
        guard source.identity == target.identity,source.revision < target.revision,joint.kind == .joint,connector.kind == .joint,joint != connector,
              acceptedTime.isFinite,observed.isFinite,threshold.isFinite,threshold >= 0,abs(observed) > threshold else { throw .invalidInput }
        self.id=id;self.source=source;self.target=target;self.joint=joint;self.connector=connector;self.acceptedTime=acceptedTime
        self.metric=metric;self.observed=observed;self.threshold=threshold
    }
}

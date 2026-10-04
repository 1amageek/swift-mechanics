
/// Caller-declared physical path; this is not an inferred joint reaction.
public struct IdentifiedPhysicalWrench: Sendable {
    public enum TemporalMeaning: Equatable, Sendable { case force, impulse }
    public let path:EntityID
    public let body:EntityID
    public let model:ModelStamp
    public let timeSeconds:Double
    public let frame:EntityID
    public let referencePoint:Vector3
    public let wrench:SpatialWrench
    public let temporalMeaning:TemporalMeaning
    /// Components describe the load exerted on the named body.
    public init(path:EntityID,body:EntityID,model:ModelStamp,timeSeconds:Double,frame:EntityID,referencePoint:Vector3,
                wrench:SpatialWrench,temporalMeaning:TemporalMeaning) throws(ObservationError) {
        guard path.kind == .load || path.kind == .joint,body.kind == .body,frame.kind == .frame,timeSeconds.isFinite else { throw .invalidInput }
        self.path=path;self.body=body;self.model=model;self.timeSeconds=timeSeconds;self.frame=frame
        self.referencePoint=referencePoint;self.wrench=wrench;self.temporalMeaning=temporalMeaning
    }
}

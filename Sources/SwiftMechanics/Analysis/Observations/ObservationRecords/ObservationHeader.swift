
public struct ObservationHeader: Sendable {
    public enum AccelerationAuthority: Equatable, Sendable { case suppliedState, constraintSolved }
    public enum TemporalMeaning: Equatable, Sendable { case instantaneousContinuous, instantaneousImpulse }
    public let model: ModelStamp
    public let timeSeconds: Double
    public let sensor: EntityID
    public let body: EntityID
    public let expressedFrame: EntityID
    public let accelerationAuthority: AccelerationAuthority
    public let temporalMeaning: TemporalMeaning
    internal init(source: ObservationSource, mount: ObservationMount, frame: EntityID, temporal: TemporalMeaning = .instantaneousContinuous) {
        model=source.model.stamp;timeSeconds=source.state.state.time;sensor=mount.sensor;body=mount.body;expressedFrame=frame
        accelerationAuthority=source.accelerationAuthority;temporalMeaning=temporal
    }
}

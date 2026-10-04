
/// Explicit instantaneous field binding. The time derivative is never integrated here.
public struct ObservationGravity: Sendable {
    public let model: ModelStamp
    public let timeSeconds: Double
    public let field: AffineGravity
    public init(model: ModelStamp, timeSeconds: Double, field: AffineGravity) throws(ObservationError) {
        guard timeSeconds.isFinite else { throw .invalidInput }
        self.model=model;self.timeSeconds=timeSeconds;self.field=field
    }
}

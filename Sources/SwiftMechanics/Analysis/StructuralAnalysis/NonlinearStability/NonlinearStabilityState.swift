/// An accepted immutable state. No failed operation can mutate the previous state.
public final class NonlinearStabilityState: Sendable {
    public let source: NonlinearStabilitySource
    public let policy: NonlinearStabilityPolicy
    public let point: NonlinearStabilityPoint
    /// Normalized q, reaction multipliers, normalized parameter; multipliers do not enter the arc norm.
    public let tangent: [Double]
    public let arcDistance: Double
    public let acceptedPoints: Int
    internal let lineage: Lineage
    internal let stepIdentity: Lineage
    internal let precedingStepIdentity: Lineage?
    internal final class Lineage: Sendable {}
    internal init(source: NonlinearStabilitySource, policy: NonlinearStabilityPolicy, point: NonlinearStabilityPoint,
                  tangent: [Double], arcDistance: Double, acceptedPoints: Int, lineage: Lineage, precedingStepIdentity: Lineage? = nil) {
        self.source=source;self.policy=policy;self.point=point;self.tangent=tangent
        self.arcDistance=arcDistance;self.acceptedPoints=acceptedPoints;self.lineage=lineage
        self.stepIdentity=Lineage();self.precedingStepIdentity=precedingStepIdentity
    }
}

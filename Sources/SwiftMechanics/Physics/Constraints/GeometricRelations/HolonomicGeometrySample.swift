public struct HolonomicGeometrySample: Sendable {
    public let source: KinematicState
    public let snapshot: KinematicSnapshot
    public let metadata: String
    public let values: [Double]
    public let velocity: VelocityConstraintSample
    /// Independently retained full physical axis cross residual for each alignment relation.
    public let alignmentResiduals: [Vector3]
    public init(source: KinematicState, snapshot: KinematicSnapshot, metadata: String,
                values: [Double], velocity: VelocityConstraintSample, alignmentResiduals:[Vector3] = []) {
        self.source=source;self.snapshot=snapshot;self.metadata=metadata;self.values=values;self.velocity=velocity;self.alignmentResiduals=alignmentResiduals
    }
}

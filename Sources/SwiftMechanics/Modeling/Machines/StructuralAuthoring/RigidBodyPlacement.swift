public enum RigidBodyPlacement: Equatable, Sendable {
    /// Maps the root body frame into world coordinates.
    case world(bodyToWorld: RigidTransform)
    /// Uses the explicitly supplied joint anchors and initial chart.
    case connected
}

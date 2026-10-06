public enum RollingRowKind: Equatable, Sendable {
    /// Integrable support-gap derivative; positive normal points out of the plane half-space.
    case normalNoPenetration
    /// Nonholonomic no slip along the positive axle-cross-normal tangent.
    case forwardNoSlip
    /// Nonholonomic no slip along normal-cross-forward.
    case lateralNoSlip
}

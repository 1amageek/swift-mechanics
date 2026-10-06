/// Trilinear displacement solid with full 2x2x2 Gauss integration.
/// Volumetric/bending locking can occur; no mixed-pressure or hourglass correction is applied.
public enum HexahedralFormulation: Equatable, Sendable {
    case trilinearFullIntegration

    public var interpolationOrderPerNaturalAxis: Int { 1 }
    public var gaussPointsPerNaturalAxis: Int { 2 }
}

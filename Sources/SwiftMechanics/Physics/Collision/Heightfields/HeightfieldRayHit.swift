public struct HeightfieldRayHit: Sendable {
    public let distance: Double
    public let surface: HeightfieldPoint
    public let exactParameterTieCount: Int
    public let originalRayResidual: Double
}

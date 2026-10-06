/// Original support points and features; weights reconstruct both witness points.
public struct ConvexSupportWeight: Sendable {
    public let first: ConvexSupport
    public let second: ConvexSupport
    public let weight: Double
}

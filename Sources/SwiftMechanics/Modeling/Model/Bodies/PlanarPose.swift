public struct PlanarPose: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let angle: Double

    public init(x: Double, y: Double, angle: Double) throws(ModelError) {
        guard x.isFinite, y.isFinite, angle.isFinite else { throw .nonFiniteCoordinates }
        self.x = x
        self.y = y
        self.angle = angle
    }
}

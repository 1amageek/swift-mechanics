public struct QuaternionRate: Equatable, Sendable {
    public let w: Double
    public let x: Double
    public let y: Double
    public let z: Double

    public init(w: Double, x: Double, y: Double, z: Double) throws(CoreError) {
        guard w.isFinite, x.isFinite, y.isFinite, z.isFinite else { throw .nonFiniteResult }
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }
}

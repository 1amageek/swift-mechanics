public struct SpatialBeamLocation: Equatable, Sendable {
    /// Axial reference fraction; section coordinates y,z are metres in the principal frame.
    public let xi: Double
    public let y: Double
    public let z: Double
    public init(xi: Double, y: Double, z: Double) throws(SpatialBeamError) {
        guard xi.isFinite, xi >= 0, xi <= 1, y.isFinite, z.isFinite else {
            throw .invalidInput(parameter: "fieldLocation")
        }
        self.xi = xi; self.y = y; self.z = z
    }
}

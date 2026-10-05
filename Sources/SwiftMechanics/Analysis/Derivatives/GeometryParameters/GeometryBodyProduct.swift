public struct GeometryBodyProduct: Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let translation: Vector3
    /// Matrix direction dR, with R mapping body coordinates to world coordinates.
    public let rotationMatrix: Matrix3
    public let velocity: SpatialMotion
    public let acceleration: SpatialMotion
    public let prescribedDrift: SpatialMotion
    public let accelerationBias: SpatialMotion
    internal init(body: EntityID, frame: EntityID, translation: Vector3, rotationMatrix: Matrix3,
                  velocity: SpatialMotion, acceleration: SpatialMotion, prescribedDrift: SpatialMotion, accelerationBias: SpatialMotion) {
        self.body = body; self.frame = frame; self.translation = translation; self.rotationMatrix = rotationMatrix
        self.velocity = velocity; self.acceleration = acceleration; self.prescribedDrift = prescribedDrift; self.accelerationBias = accelerationBias
    }
}

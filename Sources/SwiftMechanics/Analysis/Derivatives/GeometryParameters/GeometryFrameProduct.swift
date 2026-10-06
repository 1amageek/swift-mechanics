public struct GeometryFrameProduct: Sendable {
    public let frame: EntityID
    public let referenceFrame: EntityID
    public let translation: Vector3
    public let rotationMatrix: Matrix3
    public let velocity: SpatialMotion
    public let acceleration: SpatialMotion
    internal init(frame: EntityID, referenceFrame: EntityID, jet: GeometryFrameJet) {
        self.frame = frame; self.referenceFrame = referenceFrame
        translation = jet.translation.direction; rotationMatrix = jet.rotation.direction
        velocity = jet.velocity.direction; acceleration = jet.acceleration.direction
    }
}

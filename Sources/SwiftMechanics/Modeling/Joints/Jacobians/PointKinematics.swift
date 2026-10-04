
public struct PointKinematics: Equatable, Sendable {
    public let body: EntityID
    public let referenceFrame: EntityID
    public let position: Vector3
    public let velocity: Vector3
    public let acceleration: Vector3
    public let accelerationBias: Vector3
    public let prescribedDriftVelocity: Vector3

    internal init(body: EntityID, referenceFrame: EntityID, position: Vector3, velocity: Vector3,
                  acceleration: Vector3, accelerationBias: Vector3, prescribedDriftVelocity: Vector3) {
        self.body = body; self.referenceFrame = referenceFrame; self.position = position; self.velocity = velocity
        self.acceleration = acceleration; self.accelerationBias = accelerationBias
        self.prescribedDriftVelocity = prescribedDriftVelocity
    }
}

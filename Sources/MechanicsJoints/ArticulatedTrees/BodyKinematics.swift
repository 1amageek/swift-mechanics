import MechanicsCore
import MechanicsModel

public struct BodyKinematics: Equatable, Sendable {
    public let body: EntityID
    public let bodyFrame: EntityID
    public let worldFrame: EntityID
    public let motion: FrameMotion
    public let prescribedDriftVelocity: SpatialMotion
    public let accelerationBias: SpatialMotion

    internal init(body: EntityID, bodyFrame: EntityID, worldFrame: EntityID, motion: FrameMotion,
                  prescribedDriftVelocity: SpatialMotion, accelerationBias: SpatialMotion) {
        self.body = body; self.bodyFrame = bodyFrame; self.worldFrame = worldFrame; self.motion = motion
        self.prescribedDriftVelocity = prescribedDriftVelocity; self.accelerationBias = accelerationBias
    }
}

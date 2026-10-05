public struct AttachmentRigidLoad: Sendable {
    public let attachment: String
    public let body: EntityID
    public let bodyFrame: EntityID
    public let referenceFrame: EntityID
    /// Moment is about the current body origin; both fields are expressed in reference-frame axes.
    public let wrench: SpatialWrench
    public let pointWorld: Vector3
    public let physicalPower: Double
    public let prescribedPower: Double

    internal init(attachment: String, body: EntityID, bodyFrame: EntityID, referenceFrame: EntityID,
                  wrench: SpatialWrench, point: Vector3, power: Double, prescribedPower: Double) {
        self.attachment = attachment; self.body = body; self.bodyFrame = bodyFrame
        self.referenceFrame = referenceFrame; self.wrench = wrench; self.pointWorld = point
        self.physicalPower = power; self.prescribedPower = prescribedPower
    }
}

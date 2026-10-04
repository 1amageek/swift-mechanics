public struct GranularBoundaryReaction: Sendable {
    public let body: ModelReference
    public let frame: ModelReference
    public let referencePoint: Vector3
    public let force: Vector3, torque: Vector3
    public let prescribedPower: Double
    internal init(body: ModelReference, frame: ModelReference, referencePoint: Vector3, force: Vector3, torque: Vector3, prescribedPower: Double) {
        self.body=body; self.frame=frame; self.referencePoint=referencePoint; self.force=force; self.torque=torque; self.prescribedPower=prescribedPower
    }
}

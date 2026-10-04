public struct BodyWrenchContribution: Equatable, Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let referencePoint: Vector3
    public let wrench: SpatialWrench
    public let channel: ForceChannel
    public let potentialEnergy: Double?
    public let dissipatedPower: Double?
    public init(body: EntityID, frame: EntityID, referencePoint: Vector3, wrench: SpatialWrench,
                channel: ForceChannel, potentialEnergy: Double? = nil, dissipatedPower: Double? = nil) throws(DynamicsError) {
        guard body.kind == .body, frame.kind == .frame else { throw .invalidInput }
        if let e = potentialEnergy { guard e.isFinite else { throw .invalidInput } }
        if let d = dissipatedPower { guard d.isFinite, d >= 0 else { throw .invalidInput } }
        self.body = body; self.frame = frame; self.referencePoint = referencePoint; self.wrench = wrench
        self.channel = channel; self.potentialEnergy = potentialEnergy; self.dissipatedPower = dissipatedPower
    }
}

public struct StructuralConstantTorque: Sendable {
    public let id: EntityID
    public let joint: EntityID
    public let torqueNm: Double
    internal init(id: EntityID, joint: EntityID, torqueNm: Double) {
        self.id = id; self.joint = joint; self.torqueNm = torqueNm
    }
}

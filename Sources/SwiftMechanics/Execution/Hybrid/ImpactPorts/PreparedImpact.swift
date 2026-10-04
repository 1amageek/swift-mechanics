
public struct PreparedImpact: Sendable {
    public let model: ModelStamp
    public let collisionRevision: UInt64
    public let system: RigidDynamicsSystem
    public let contacts: [ImpulseContactBinding]
    /// Contact-major rows; each entry maps generalized velocity to separating speed (m/s).
    public let normalRows: [Double]
    internal init(input: HardImpactInput, system: RigidDynamicsSystem, rows: [Double]) {
        model=input.model.stamp; collisionRevision=input.expectedCollisionRevision; self.system=system
        contacts=input.contacts.sorted { $0.eventID < $1.eventID }; normalRows=rows
    }
}

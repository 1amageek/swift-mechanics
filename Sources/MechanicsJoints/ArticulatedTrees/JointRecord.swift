import MechanicsModel

public struct JointRecord: Equatable, Sendable {
    public let id: EntityID
    public let parentBody: EntityID
    public let childBody: EntityID
    public let parentAnchor: JointAnchor
    public let childAnchor: JointAnchor
    public let manifold: JointManifold

    public init(id: EntityID, parentBody: EntityID, childBody: EntityID,
                parentAnchor: JointAnchor, childAnchor: JointAnchor, manifold: JointManifold) throws(JointError) {
        guard id.kind == .joint, parentBody.kind == .body, childBody.kind == .body else { throw .identityKindMismatch }
        self.id = id; self.parentBody = parentBody; self.childBody = childBody
        self.parentAnchor = parentAnchor; self.childAnchor = childAnchor; self.manifold = manifold
    }
}

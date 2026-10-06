/// A named joint's immutable inputs; the physical manifold stays supplier-owned.
public struct StructuralJointConfiguration: Equatable, Sendable {
    public let id: EntityID
    public let parentFrame: EntityID
    public let childFrame: EntityID
    public let parentAnchorToBody: RigidTransform
    public let childAnchorToBody: RigidTransform
    public let manifold: JointManifold
    public let authority: CoordinateAuthority
    public let initial: JointInitialState

    public init(id: EntityID, parentFrame: EntityID, childFrame: EntityID,
                parentAnchorToBody: RigidTransform, childAnchorToBody: RigidTransform,
                specification: JointSpecification, authority: CoordinateAuthority,
                initial: JointInitialState) throws(MachineDefinitionFailure) {
        guard id.kind == .joint, parentFrame.kind == .frame, childFrame.kind == .frame else {
            throw .invalidJoint(.identityKindMismatch)
        }
        let manifold: JointManifold
        do { manifold = try JointManifold(specification) }
        catch {
            throw .compilation(.one(.invalidInput, .input, records: [id],
                message: "Structural joint axes or geometry failed manifold admission."))
        }
        guard initial.coordinates.q.count == manifold.positionCount,
              initial.coordinates.v.count == manifold.velocityCount,
              initial.acceleration.count == manifold.velocityCount else { throw .invalidJoint(.invalidCoordinateCount) }
        guard (manifold.velocityCount == 0) == (authority == .fixed) else {
            throw .compilation(.one(.incompatibleCoordinateAuthority, .modes, records: [id],
                message: "Structural joint chart and supplied authority disagree."))
        }
        self.id = id; self.parentFrame = parentFrame; self.childFrame = childFrame
        self.parentAnchorToBody = parentAnchorToBody; self.childAnchorToBody = childAnchorToBody
        self.manifold = manifold; self.authority = authority; self.initial = initial
    }
}

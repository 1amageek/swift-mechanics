/// Spatial spherical physical pair using the supplier's actual manifold.
public struct SphericalJoint<Content: Machine>: StructuralJointMachine {
    public typealias Body = Never
    public let configuration: StructuralJointConfiguration
    public let content: Content

    public init(id: EntityID, parentFrame: EntityID, childFrame: EntityID,
                parentAnchorToBody: RigidTransform, childAnchorToBody: RigidTransform,
                authority: CoordinateAuthority, initial: JointInitialState,
                @MachineBuilder content: () -> Content) throws(MachineDefinitionFailure) {
        configuration = try StructuralJointConfiguration(id: id, parentFrame: parentFrame,
            childFrame: childFrame, parentAnchorToBody: parentAnchorToBody,
            childAnchorToBody: childAnchorToBody, specification: .spherical,
            authority: authority, initial: initial)
        self.content = content()
    }
}

/// Immutable declarations; original physical acceptance belongs to recovery.
public struct PlanarPrescribedRootReactionInput: Sendable {
    public let motion: PhysicalConstrainedMotion
    public let geometry: GeometricConstraintSystem
    public let state: KinematicState
    public let constraint: PrescribedRootConstraint
    public let originalDrive: [Double]
    public let topology: TreeReactionTopology
    public var dynamics: PhysicalRigidDynamicsSystem { constraint.system }
    public init(motion: PhysicalConstrainedMotion, geometry: GeometricConstraintSystem, state: KinematicState,
                constraint: PrescribedRootConstraint, originalDrive: [Double], topology: TreeReactionTopology) {
        self.motion=motion;self.geometry=geometry;self.state=state;self.constraint=constraint
        self.originalDrive=originalDrive;self.topology=topology
    }
}

/// Immutable declarations; physical acceptance is owned by the recovery operation.
public struct PlanarClosedLoopReactionInput: Sendable {
    public let motion: PhysicalConstrainedMotion
    public let geometry: GeometricConstraintSystem
    public let state: KinematicState
    public let allocation: GeometricPhysicalAllocationWitness
    public let originalDrive: [Double]
    public let topology: ClosedLoopReactionTopology
    public var dynamics: PhysicalRigidDynamicsSystem { motion.system }
    public init(motion: PhysicalConstrainedMotion, geometry: GeometricConstraintSystem, state: KinematicState,
                allocation: GeometricPhysicalAllocationWitness, originalDrive: [Double], topology: ClosedLoopReactionTopology) {
        self.motion=motion;self.geometry=geometry;self.state=state;self.allocation=allocation
        self.originalDrive=originalDrive;self.topology=topology
    }
}

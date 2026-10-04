/// Immutable declarations. Construction does not establish physical acceptance.
public struct ClosedLoopReactionInput: Sendable {
    public let dynamics: RigidDynamicsSystem
    public let geometry: GeometricConstraintSystem
    public let state: KinematicState
    public let physicalRows: GeometricPhysicalRowWitness
    public let motion: ConstrainedMotion
    /// Original generalized drive declaration; identified body loads belong in dynamics.input instead.
    public let originalDrive: [Double]
    public let topology: ClosedLoopReactionTopology
    public init(dynamics: RigidDynamicsSystem, geometry: GeometricConstraintSystem, state: KinematicState,
                physicalRows: GeometricPhysicalRowWitness, motion: ConstrainedMotion,
                originalDrive: [Double], topology: ClosedLoopReactionTopology) {
        self.dynamics=dynamics; self.geometry=geometry; self.state=state; self.physicalRows=physicalRows
        self.motion=motion; self.originalDrive=originalDrive; self.topology=topology
    }
}

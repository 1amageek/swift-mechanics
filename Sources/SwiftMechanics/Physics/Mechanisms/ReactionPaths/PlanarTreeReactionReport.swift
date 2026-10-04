public struct PlanarTreeReactionReport: Sendable {
    public enum Fidelity: Equatable, Sendable { case reducedPlanarRigidTreeBalance }
    public let fidelity: Fidelity = .reducedPlanarRigidTreeBalance
    public let system: PhysicalRigidDynamicsSystem
    public let joints: [PlanarJointReactionWrench]
    public let support: PlanarRootSupportWrench?
    public let maximumScaledOriginalGeneralizedResidual: Double
    public let numericalWork: NumericalWork
    public let loadWork: LoadWork
    /// Caller assumption, not a certificate of unseen physical connections.
    public let topologyAssumption: TreeReactionTopology
}

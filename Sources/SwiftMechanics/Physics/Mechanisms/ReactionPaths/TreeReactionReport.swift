public struct TreeReactionReport: Sendable {
    public let fidelity: TreeReactionFidelity = .spatialRigidTreeBalance
    public let joints: [JointReactionWrench]
    public let support: RootSupportWrench?
    public let maximumScaledOriginalGeneralizedResidual: Double
    public let numericalWork: NumericalWork
    public let loadWork: LoadWork
    /// This is the caller's physical completeness assumption, not an inferred certificate.
    public let topologyAssumption: TreeReactionTopology
}

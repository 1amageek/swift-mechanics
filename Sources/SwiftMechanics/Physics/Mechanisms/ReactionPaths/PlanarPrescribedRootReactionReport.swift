/// Net support and complete-tree cuts; no individual bearing or actuator split is inferred.
public struct PlanarPrescribedRootReactionReport: Sendable {
    public enum Fidelity: Equatable, Sendable { case reducedPlanarPrescribedRootBalance }
    public let fidelity: Fidelity = .reducedPlanarPrescribedRootBalance
    public let source: PlanarPrescribedRootReactionInput
    public let joints: [PlanarJointReactionWrench]
    public let support: PlanarRootSupportWrench
    public let rootActuationEffort: [Double]
    public let originalRank: ConstraintRankEvidence
    public let maximumScaledOriginalGeneralizedResidual: Double
    public let maximumScaledRootEffortResidual: Double
    public let numericalWork: NumericalWork
    public let loadWork: LoadWork
}

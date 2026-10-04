public struct PlanarPrescribedRootReactionPolicy: Sendable {
    public let geometry: ConstraintEvaluationPolicy
    public let mechanism: MechanismSolvePolicy
    public let tree: TreeReactionPolicy
    public init(geometry: ConstraintEvaluationPolicy, mechanism: MechanismSolvePolicy,
                tree: TreeReactionPolicy) throws(PlanarPrescribedRootReactionError) {
        guard geometry.expectedLayoutRevision == mechanism.constraints.evaluation.expectedLayoutRevision,
              mechanism.constraints.diagonalMetric.count == mechanism.dynamics.coordinateScales.count,
              tree.generalizedForceScales.count == mechanism.dynamics.coordinateScales.count else { throw .invalidShape }
        self.geometry=geometry;self.mechanism=mechanism;self.tree=tree
    }
}

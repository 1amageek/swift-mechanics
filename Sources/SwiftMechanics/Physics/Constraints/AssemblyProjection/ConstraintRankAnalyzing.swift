
public protocol ConstraintRankAnalyzing: Sendable {
    /// Reports numerical row independence without projecting state or inferring force.
    func rank(_ sample: VelocityConstraintSample, policy: ConstraintSolvePolicy,
              work: inout NumericalWork) throws(ConstraintError) -> ConstraintRankEvidence
}

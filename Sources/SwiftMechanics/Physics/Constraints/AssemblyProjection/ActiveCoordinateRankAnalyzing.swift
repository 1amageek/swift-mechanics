public protocol ActiveCoordinateRankAnalyzing: Sendable {
    /// Numerical rank of an explicitly restricted tangent; retains all original input rows.
    func rank(_ sample: VelocityConstraintSample, activeCoordinates: [Int], policy: ConstraintSolvePolicy,
              work: inout NumericalWork) throws(ConstraintError) -> ActiveCoordinateRankEvidence
}
